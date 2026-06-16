import Foundation

/// Applies an `ApplicationTheme` to the running app. Native equivalent of
/// GitHub Desktop applying the theme to the document body; here it drives
/// `NSApp.appearance`. The concrete implementation lives in the App layer
/// because it touches AppKit.
@MainActor
protocol ThemeApplying: AnyObject {
    func apply(_ theme: ApplicationTheme)
}
