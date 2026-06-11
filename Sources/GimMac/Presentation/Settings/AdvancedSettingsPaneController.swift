import AppKit

/// Advanced pane: background repository indicators and the external Git
/// credential helper. Native equivalent of the Git-relevant rows in GitHub
/// Desktop's `Advanced` preferences panel.
@MainActor
final class AdvancedSettingsPaneController: SettingsPaneViewController {
    private let viewModel: AdvancedSettingsViewModel

    init(viewModel: AdvancedSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        addHeader("Advanced")

        addSection("Background updates", views: [
            makeCheckbox("Show status icons in the repository list", isOn: viewModel.repositoryIndicatorsEnabled) { [weak self] in
                self?.viewModel.repositoryIndicatorsEnabled = $0
            },
            makeNote("These icons indicate which repositories have local or remote changes, "
                     + "and require periodic background fetching of repositories that are not "
                     + "currently selected. Turning this off may improve performance with many repositories.")
        ])

        addSection("Network and credentials", views: [
            makeCheckbox("Use Git Credential Manager", isOn: viewModel.useExternalCredentialHelper) { [weak self] in
                self?.viewModel.useExternalCredentialHelper = $0
            },
            makeNote("Use an external Git credential helper for private repositories. "
                     + "This feature is experimental and subject to change.")
        ])
    }
}
