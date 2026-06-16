import AppKit

/// Applies an `ApplicationTheme` to the running app via `NSApp.appearance`.
/// `nil` lets the app follow the system setting. Native equivalent of GitHub
/// Desktop toggling the theme class on the document body.
@MainActor
final class AppKitThemeController: ThemeApplying {
    func apply(_ theme: ApplicationTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
