import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: NSWindowController?
    private let repositoryInspector = LocalGitRepositoryInspector()

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

    @objc
    private func showMainWindowFromMenu(_ sender: Any?) {
        ensureMainWindowVisible(forceNew: true)
    }

    private func ensureMainWindowVisible(forceNew: Bool) {
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
            viewModel: RepositoryStoreViewModel(inspector: repositoryInspector)
        )

        return NSWindowController(window: window)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "GimMac")
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "About GimMac",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Hide GimMac",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit GimMac",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let windowMenuItem = NSMenuItem()
        windowMenuItem.title = "Window"
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu

        let showMainWindow = NSMenuItem(
            title: "Show Main Window",
            action: #selector(showMainWindowFromMenu(_:)),
            keyEquivalent: "0"
        )
        showMainWindow.target = self
        windowMenu.addItem(showMainWindow)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}
