import AppKit

/// Accessibility pane: underline links and show check marks in the diff.
/// Native equivalent of GitHub Desktop's `Accessibility` preferences panel.
@MainActor
final class AccessibilitySettingsPaneController: SettingsPaneViewController {
    private let viewModel: AccessibilitySettingsViewModel

    init(viewModel: AccessibilitySettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        addHeader("Accessibility")

        addSection(nil, views: [
            makeCheckbox("Underline links", isOn: viewModel.underlineLinks) { [weak self] in
                self?.viewModel.underlineLinks = $0
            },
            makeNote("Underline links in commit messages, comments, and other text to make them "
                     + "easier to distinguish."),
            makeCheckbox("Show check marks beside diff line numbers", isOn: viewModel.showDiffCheckMarks) { [weak self] in
                self?.viewModel.showDiffCheckMarks = $0
            },
            makeNote("When enabled, check marks appear alongside line numbers in the diff while "
                     + "committing. When disabled, the line-number controls are less prominent.")
        ])
    }
}
