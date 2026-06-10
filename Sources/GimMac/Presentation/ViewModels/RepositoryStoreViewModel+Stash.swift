import Foundation

// Stash apply / drop / push.

@MainActor
extension RepositoryStoreViewModel {
    func applyStash() async {
        guard let repository = selectedRepository, let stashProvider else { return }
        errorMessage = nil
        do {
            try await stashProvider.applyStash(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dropStash() async {
        guard let repository = selectedRepository, let stashProvider else { return }
        errorMessage = nil
        do {
            try await stashProvider.dropStash(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
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
