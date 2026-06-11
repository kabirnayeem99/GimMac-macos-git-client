import AppKit

/// Prompts pane: per-action confirmation toggles, the uncommitted-changes
/// branch-switch strategy, and the commit-length warning. Native equivalent of
/// GitHub Desktop's `Prompts` preferences panel.
@MainActor
final class PromptsSettingsPaneController: SettingsPaneViewController {
    private let viewModel: PromptsSettingsViewModel

    private static let strategyTitles = [
        "Ask me where I want the changes to go",
        "Always bring my changes to the new branch",
        "Always stash and leave my changes on the current branch"
    ]
    private static let strategyOrder: [UncommittedChangesStrategy] = [
        .askForConfirmation, .moveToNewBranch, .stashOnCurrentBranch
    ]

    init(viewModel: PromptsSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        addHeader("Prompts")

        addSection("Show a confirmation dialog before…", views: [
            makeCheckbox("Removing repositories", isOn: viewModel.confirmRepositoryRemoval) { [weak self] in
                self?.viewModel.confirmRepositoryRemoval = $0
            },
            makeCheckbox("Discarding changes", isOn: viewModel.confirmDiscardChanges) { [weak self] in
                self?.viewModel.confirmDiscardChanges = $0
            },
            makeCheckbox("Discarding changes permanently", isOn: viewModel.confirmDiscardChangesPermanently) { [weak self] in
                self?.viewModel.confirmDiscardChangesPermanently = $0
            },
            makeCheckbox("Discarding stash", isOn: viewModel.confirmDiscardStash) { [weak self] in
                self?.viewModel.confirmDiscardStash = $0
            },
            makeCheckbox("Checking out a commit", isOn: viewModel.confirmCheckoutCommit) { [weak self] in
                self?.viewModel.confirmCheckoutCommit = $0
            },
            makeCheckbox("Force pushing", isOn: viewModel.confirmForcePush) { [weak self] in
                self?.viewModel.confirmForcePush = $0
            },
            makeCheckbox("Undoing a commit", isOn: viewModel.confirmUndoCommit) { [weak self] in
                self?.viewModel.confirmUndoCommit = $0
            },
            makeCheckbox("Committing changes hidden by a filter", isOn: viewModel.confirmCommitFilteredChanges) { [weak self] in
                self?.viewModel.confirmCommitFilteredChanges = $0
            }
        ])

        let selectedStrategyIndex = Self.strategyOrder.firstIndex(of: viewModel.uncommittedChangesStrategy) ?? 0
        addSection("If I have changes and I switch branches…", views: [
            makePopUp(titles: Self.strategyTitles, selectedIndex: selectedStrategyIndex) { [weak self] index in
                guard let self, Self.strategyOrder.indices.contains(index) else { return }
                viewModel.uncommittedChangesStrategy = Self.strategyOrder[index]
            }
        ])

        addSection("Commit", views: [
            makeCheckbox("Show commit length warning", isOn: viewModel.showCommitLengthWarning) { [weak self] in
                self?.viewModel.showCommitLengthWarning = $0
            }
        ])
    }
}
