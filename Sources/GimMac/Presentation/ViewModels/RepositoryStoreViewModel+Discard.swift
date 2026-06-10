import Foundation

// Discarding working-tree changes (single file and whole tree).

@MainActor
extension RepositoryStoreViewModel {
    func discardChanges(path: String) async {
        guard let repository = selectedRepository,
              let discardProvider,
              let file = changedFiles.first(where: { $0.path == path }) else { return }
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
        guard let repository = selectedRepository, let discardProvider else { return }
        errorMessage = nil
        do {
            try await discardProvider.discardAllChanges(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
