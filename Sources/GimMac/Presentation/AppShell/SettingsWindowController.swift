import AppKit

@MainActor
enum SettingsPane: String, CaseIterable {
    case git = "Git"
    case integrations = "Integrations"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case prompts = "Prompts"
    case advanced = "Advanced"
    case accessibility = "Accessibility"

    var symbolName: String {
        switch self {
        case .git: return "point.topleft.down.curvedto.point.bottomright.up"
        case .integrations: return "square.stack.3d.up"
        case .appearance: return "paintbrush"
        case .notifications: return "bell"
        case .prompts: return "questionmark.circle"
        case .advanced: return "gearshape.2"
        case .accessibility: return "figure.roll"
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(environment: SettingsEnvironment) {
        let rootViewController = SettingsRootViewController(environment: environment)
        let window = NSWindow(contentViewController: rootViewController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 960, height: 620))
        window.styleMask = [.titled, .closable, .resizable]
        window.identifier = NSUserInterfaceItemIdentifier("gimmac.settings.window")
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        super.init(window: window)
        shouldCascadeWindows = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
