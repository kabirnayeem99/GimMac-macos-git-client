import Foundation

// Stash apply / drop / push.

@MainActor
extension RepositoryStoreViewModel {
    func applyStash() async {
        guard !isStashOperationInProgress else { return }
        guard let repository = selectedRepository, let stashProvider else { return }
        isStashOperationInProgress = true
        defer { isStashOperationInProgress = false }
        errorMessage = nil
        do {
            try await stashProvider.applyStash(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dropStash() async {
        guard !isStashOperationInProgress else { return }
        guard let repository = selectedRepository, let stashProvider else { return }
        isStashOperationInProgress = true
        defer { isStashOperationInProgress = false }
        errorMessage = nil
        do {
            try await stashProvider.dropStash(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Factory for the stash-management sheet VM. Returns `nil` when the host
    /// did not inject the stash service (e.g. preview / test scaffolding) or no
    /// repository is selected — callers should disable the affordance then.
    func makeStashManagementViewModel() -> StashManagementViewModel? {
        guard let stashProvider, let repository = selectedRepository else { return nil }
        let viewModel = StashManagementViewModel(stashProvider: stashProvider)
        viewModel.repositoryURL = repository.url
        return viewModel
    }

    /// Stash all working-tree changes (Branch → Stash All Changes).
    func stashAllChanges() async {
        guard let repository = selectedRepository, let stashProvider else { return }
        errorMessage = nil
        do {
            try await stashProvider.pushStash(in: repository.url, message: nil)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
