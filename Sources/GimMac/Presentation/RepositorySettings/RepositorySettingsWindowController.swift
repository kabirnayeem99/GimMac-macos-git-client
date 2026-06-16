import AppKit

@MainActor
final class RepositorySettingsWindowController: NSWindowController {
    private let viewModel: RepositorySettingsViewModel

    init(viewModel: RepositorySettingsViewModel) {
        self.viewModel = viewModel
        let contentVC = RepositorySettingsViewController(viewModel: viewModel)
        let window = NSWindow(contentViewController: contentVC)
        window.title = "Repository Settings"
        window.setContentSize(NSSize(width: 560, height: 400))
        window.styleMask = [.titled, .closable]
        window.identifier = NSUserInterfaceItemIdentifier("gimmac.repositorySettings.window")
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.isRestorable = false
        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
