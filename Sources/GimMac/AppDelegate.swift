import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force app icon assignment at launch so Dock/window use the expected
        // branding even when LaunchServices icon cache is stale.
        if let appIcon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = appIcon
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GimMac"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}
