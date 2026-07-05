import Foundation

// Discarding working-tree changes (single file and whole tree).

@MainActor
extension RepositoryStoreViewModel {
    func discardChanges(path: String) async {
        guard !isWorkingTreeMutationInProgress else { return }
        guard let repository = selectedRepository,
              let discardProvider,
              let file = changedFiles.first(where: { $0.path == path }) else { return }
        isWorkingTreeMutationInProgress = true
        defer { isWorkingTreeMutationInProgress = false }
        errorMessage = nil
        do {
            try await discardProvider.discardChanges(in: repository.url, for: path, status: file.status)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Discard every change in the working tree (Branch → Discard All Changes).
    func discardAllChanges() async {
        guard !isWorkingTreeMutationInProgress else { return }
        guard let repository = selectedRepository, let discardProvider else { return }
        isWorkingTreeMutationInProgress = true
        defer { isWorkingTreeMutationInProgress = false }
        errorMessage = nil
        do {
            try await discardProvider.discardAllChanges(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
