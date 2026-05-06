import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    private var settingsWindowController: SettingsWindowController?
    private let repositoryInspector = LocalGitRepositoryInspector()
    private let gitClient = ProcessGitClient()
    private lazy var repositoryPersistence = CoreDataRepositoryPersistence(gitClient: gitClient)

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }

        NSApp.setActivationPolicy(.regular)
        installMainMenu()
        ensureMainWindowVisible(forceNew: true)
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
            viewModel: RepositoryStoreViewModel(
                inspector: repositoryInspector,
                screenRepository: LiveRepositoryScreenDataRepository(
                    statusProvider: GitStatusProvider(client: gitClient),
                    historyProvider: GitHistoryProvider(client: gitClient),
                    gitClient: gitClient
                ),
                diffProvider: GitDiffProvider(client: gitClient),
                commitProvider: GitCommitProvider(client: gitClient),
                repositoryPersistence: repositoryPersistence
            )
        )

        return NSWindowController(window: window)
    }

    // MARK: - Menu Actions

    func installMainMenu() {
        let mainMenu = MainMenuFactory.buildMainMenu(
            actionTarget: self,
            placeholderAction: #selector(placeholderMenuAction(_:)),
            aboutAction: #selector(showAboutPanel(_:)),
            settingsAction: #selector(showSettingsWindow(_:))
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
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
