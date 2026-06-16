import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    init(viewModel: OnboardingViewModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to GimMac"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(rootView: OnboardingView(viewModel: viewModel))
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }
}
