import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private let gitClient = ProcessGitClient()
    private let editorService = NSWorkspaceExternalEditorService()

    private static let onboardingCompletedKey = "io.github.kabirnayeem99.gimmac.onboardingCompleted"
    private lazy var repositoryInspector = LocalGitRepositoryInspector(gitClient: gitClient)
    private lazy var repositoryPersistence = CoreDataRepositoryPersistence(gitClient: gitClient)

    private lazy var repositoryStoreViewModel: RepositoryStoreViewModel = RepositoryStoreViewModel(
        inspector: repositoryInspector,
        screenRepository: LiveRepositoryScreenDataRepository(
            statusProvider: GitStatusProvider(client: gitClient),
            historyProvider: GitHistoryProvider(client: gitClient),
            upstreamProvider: GitBranchUpstreamReader(client: gitClient),
            gitClient: gitClient
        ),
        diffProvider: GitDiffProvider(client: gitClient),
        commitInspector: GitCommitInspector(client: gitClient),
        commitProvider: GitCommitProvider(client: gitClient),
        repositoryPersistence: repositoryPersistence,
        discardProvider: GitDiscardProvider(client: gitClient),
        stashProvider: GitStashProvider(client: gitClient),
        branchProvider: GitBranchReader(client: gitClient),
        branchOperator: GitBranchOperator(client: gitClient),
        statusProvider: GitStatusProvider(client: gitClient)
    )

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }

        NSApp.setActivationPolicy(.regular)
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
        if !flag || NSApp.windows.allSatisfy({ !$0.isVisible }) {
            ensureMainWindowVisible(forceNew: true)
        } else {
            ensureMainWindowVisible(forceNew: false)
        }
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
            viewModel: repositoryStoreViewModel
        )

        return NSWindowController(window: window)
    }

    // MARK: - Menu Actions

    func installMainMenu() {
        let mainMenu = MainMenuFactory.buildMainMenu(
            actionTarget: self,
            placeholderAction: #selector(placeholderMenuAction(_:)),
            aboutAction: #selector(showAboutPanel(_:)),
            settingsAction: #selector(showSettingsWindow(_:)),
            openInEditorAction: #selector(openInExternalEditor(_:))
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
            settingsWindowController = SettingsWindowController(editorService: editorService)
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    func openInExternalEditor(_ sender: Any?) {
        guard let repo = repositoryStoreViewModel.selectedRepository else { return }
        let editors = editorService.availableEditors()
        let savedID = UserDefaults.standard.string(forKey: ExternalEditorPreferences.selectedEditorKey)
        guard let editor = editors.first(where: { $0.bundleIdentifier == savedID }) ?? editors.first else { return }
        editorService.launch(editor: editor, at: repo.url)
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
