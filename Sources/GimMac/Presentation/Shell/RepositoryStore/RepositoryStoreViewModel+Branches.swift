import Foundation

// Branches-panel factory and current-branch derivation.

@MainActor
extension RepositoryStoreViewModel {
    /// Factory for the branches panel VM. Returns `nil` when the host did not
    /// inject the branch services (e.g. preview / test scaffolding) — callers
    /// should hide the affordance in that case.
    func makeBranchesViewModel() -> BranchesViewModel? {
        guard let branchProvider, let branchOperator, let statusProvider else { return nil }
        let viewModel = BranchesViewModel(
            branchProvider: branchProvider,
            branchOperator: branchOperator,
            statusProvider: statusProvider,
            compareProvider: compareProvider,
            updateFromDefaultProvider: updateFromDefaultProvider
        )
        viewModel.setRepository(selectedRepository?.url, currentBranchName: currentBranchName)
        return viewModel
    }

    /// Short name of the checked-out branch, derived from `tip`. `nil` for
    /// detached / unborn / unknown states.
    private var currentBranchName: String? {
        if case .valid(let summary) = tip { return summary.name }
        return nil
    }
}
