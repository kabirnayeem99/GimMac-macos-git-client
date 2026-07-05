import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var repositorySettingsWindowController: RepositorySettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private let logger = GimMacLogger()
    private lazy var gitClient = ProcessGitClient(logger: logger)
    private let editorService = NSWorkspaceExternalEditorService()
    private let shellService = NSWorkspaceShellService()
    private lazy var remoteService = GitRemoteService(client: gitClient)
    private lazy var lfsService = GitLFSService(client: gitClient)
    private lazy var branchRenameService = GitBranchOperator(client: gitClient)

    // Settings infrastructure (composition root).
    private let settingsStore: any AppSettingsStoring = UserDefaultsAppSettingsStore()
    private let themeApplier = AppKitThemeController()
    private let notificationAuthorizer = UserNotificationAuthorizer()
    private lazy var gitConfigService = GitConfigService(client: gitClient)

    private static let onboardingCompletedKey = "io.github.kabirnayeem99.gimmac.onboardingCompleted"
    private lazy var repositoryInspector = LocalGitRepositoryInspector(gitClient: gitClient, logger: logger)
    private lazy var repositoryPersistence = CoreDataRepositoryPersistence(gitClient: gitClient)
    // Shared between the create-repository orchestrator and the view model so
    // the bundled-template cache is read once.
    private let repositoryTemplateCatalog = BundledRepositoryTemplateCatalog()

    private lazy var repositoryStoreViewModel: RepositoryStoreViewModel = RepositoryStoreViewModel(
        logger: logger,
        inspector: repositoryInspector,
        screenRepository: LiveRepositoryScreenDataRepository(
            statusProvider: GitStatusProvider(client: gitClient),
            historyProvider: GitHistoryProvider(client: gitClient),
            upstreamProvider: GitBranchUpstreamReader(client: gitClient),
            gitClient: gitClient
        ),
        diffProvider: GitDiffProvider(client: gitClient),
        commitInspector: GitCommitInspector(client: gitClient),
        commitProvider: GitCommitProvider(client: gitClient, logger: logger),
        repositoryPersistence: repositoryPersistence,
        discardProvider: GitDiscardProvider(client: gitClient),
        gitIgnoreProvider: GitIgnoreProvider(),
        stashProvider: GitStashProvider(client: gitClient),
        branchProvider: GitBranchReader(client: gitClient),
        branchOperator: GitBranchOperator(client: gitClient),
        statusProvider: GitStatusProvider(client: gitClient),
        remoteSyncProvider: GitRemoteSyncService(client: gitClient),
        compareProvider: GitBranchCompareReader(client: gitClient),
        updateFromDefaultProvider: GitUpdateFromDefaultService(client: gitClient),
        squashProvider: GitSquashProvider(client: gitClient),
        repositoryInitProvider: GitRepositoryInitService(client: gitClient),
        repositoryCloneProvider: GitRepositoryCloneService(client: gitClient),
        revertProvider: GitRevertProvider(client: gitClient),
        cherryPickProvider: GitCherryPickProvider(client: gitClient),
        tagProvider: GitTagProvider(client: gitClient),
        resetProvider: GitResetProvider(client: gitClient),
        reorderProvider: GitReorderProvider(client: gitClient),
        conflictResolver: GitConflictService(client: gitClient),
        mergeService: GitMergeService(client: gitClient),
        rebaseService: GitRebaseService(client: gitClient),
        repositoryCreator: RepositoryCreationOrchestrator(
            initProvider: GitRepositoryInitService(client: gitClient),
            scaffolding: FileRepositoryScaffolding(),
            catalog: repositoryTemplateCatalog,
            commitProvider: GitCommitProvider(client: gitClient, logger: logger),
            configReader: GitConfigService(client: gitClient)
        ),
        templateCatalog: repositoryTemplateCatalog
    )
    private var isTerminationInProgress = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }

        NSApp.setActivationPolicy(.regular)
        themeApplier.apply(settingsStore.selectedTheme)
        installMainMenu()

        if UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) {
            ensureMainWindowVisible(forceNew: true)
        } else {
            presentOnboarding()
        }
    }

    // MARK: - Onboarding

    private func presentOnboarding() {
        let configService = GitConfigService(client: gitClient)
        let viewModel = OnboardingViewModel(configReader: configService, configWriter: configService)
        viewModel.onComplete = { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
            self?.onboardingWindowController?.close()
            self?.onboardingWindowController = nil
            self?.ensureMainWindowVisible(forceNew: true)
        }
        let controller = OnboardingWindowController(viewModel: viewModel)
        onboardingWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if NSApp.windows.allSatisfy({ !$0.isVisible }) {
            ensureMainWindowVisible(forceNew: false)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ensureMainWindowVisible(forceNew: false)
        return true
    }

    // MARK: - Main Window

    func ensureMainWindowVisible(forceNew: Bool) {
        if forceNew || mainWindowController?.window == nil {
            mainWindowController = buildMainWindowController()
        }

        guard let controller = mainWindowController, let window = controller.window else { return }
        controller.showWindow(nil)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMainWindowController() -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GimMac"
        window.identifier = NSUserInterfaceItemIdentifier("gimmac.main.window")
        window.isRestorable = false
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.level = .normal
        window.isReleasedWhenClosed = false

        window.contentViewController = MainSplitViewController(
            viewModel: repositoryStoreViewModel,
            mergeService: GitMergeService(client: gitClient),
            rebaseService: GitRebaseService(client: gitClient),
            settingsStore: settingsStore
        )

        return NSWindowController(window: window)
    }

    // MARK: - Menu Actions

    func installMainMenu() {
        let mainMenu = MainMenuFactory.buildMainMenu(
            actionTarget: self,
            placeholderAction: #selector(placeholderMenuAction(_:)),
            selectors: .init(
                about: #selector(showAboutPanel(_:)),
                settings: #selector(showSettingsWindow(_:)),
                openInEditor: #selector(openInExternalEditor(_:)),
                repositorySettings: #selector(showRepositorySettings(_:))
            )
        )

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = mainMenu.item(withTitle: "Window")?.submenu
    }

    @objc
    func placeholderMenuAction(_ sender: Any?) {
        // UI-only placeholder: intentionally no behavior wired yet.
    }

    @objc
    func showSettingsWindow(_ sender: Any?) {
        if settingsWindowController == nil {
            let environment = SettingsEnvironment(
                settingsStore: settingsStore,
                configReader: gitConfigService,
                configWriter: gitConfigService,
                editorService: editorService,
                shellService: shellService,
                themeApplier: themeApplier,
                notificationAuthorizer: notificationAuthorizer
            )
            settingsWindowController = SettingsWindowController(environment: environment)
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func showRepositorySettings(_ sender: Any?) {
        guard let repo = repositoryStoreViewModel.selectedRepository else { return }

        let branchName: String
        if case .valid(let summary) = repositoryStoreViewModel.tip {
            branchName = summary.name
        } else {
            branchName = "HEAD"
        }

        let viewModel = RepositorySettingsViewModel(
            repositoryURL: repo.url,
            currentBranchName: branchName,
            remoteProvider: remoteService,
            lfsProvider: lfsService,
            branchRenamer: branchRenameService,
            editorService: editorService
        )

        let controller = RepositorySettingsWindowController(viewModel: viewModel)
        controller.onClose = { [weak self] in
            self?.repositorySettingsWindowController = nil
        }
        repositorySettingsWindowController = controller
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func openInExternalEditor(_ sender: Any?) {
        guard let repo = repositoryStoreViewModel.selectedRepository else { return }
        
        if settingsStore.useCustomEditor {
            let custom = settingsStore.customEditor
            guard !custom.path.isEmpty else { return }
            let appURL = URL(fileURLWithPath: custom.path)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            var args: [String] = []
            let rawArgs = custom.arguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for arg in rawArgs {
                if arg.contains(CustomIntegration.targetPathArgument) {
                    args.append(arg.replacingOccurrences(of: CustomIntegration.targetPathArgument, with: repo.url.path))
                } else {
                    args.append(arg)
                }
            }
            config.arguments = args
            NSWorkspace.shared.open([repo.url], withApplicationAt: appURL, configuration: config, completionHandler: nil)
        } else {
            let editors = editorService.availableEditors()
            let savedID = settingsStore.selectedExternalEditorBundleID
            guard let editor = editors.first(where: { $0.bundleIdentifier == savedID }) ?? editors.first else { return }
            editorService.launch(editor: editor, at: repo.url)
        }
    }

    @objc
    func showAboutPanel(_ sender: Any?) {
        if let controller = aboutWindowController, let window = controller.window {
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSWindowController(window: AboutWindowFactory.makeAboutPanel())
        aboutWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
extension AppDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminationInProgress else { return .terminateNow }
        isTerminationInProgress = true
        Task { [weak self] in
            await self?.gitClient.cancelAllRunningCommands()
            await MainActor.run {
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }
}
