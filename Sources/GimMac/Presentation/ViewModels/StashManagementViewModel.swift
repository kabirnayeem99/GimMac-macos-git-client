import Foundation
import Observation

/// Drives the Stash Management sheet: lists every stash and exposes
/// apply / pop / drop on a selected entry. Native equivalent of the stash
/// surface in GitHub Desktop's Changes tab, generalized to the full stack.
@MainActor
@Observable
final class StashManagementViewModel {
    private(set) var stashes: [StashEntry] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var repositoryURL: URL?

    private let stashProvider: StashProviding

    init(stashProvider: StashProviding) {
        self.stashProvider = stashProvider
    }

    func load() async {
        guard let repositoryURL, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            stashes = try await stashProvider.fetchAllStashes(in: repositoryURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Restore the stash, keeping it in the stack.
    func apply(_ entry: StashEntry) async {
        await perform(entry) { try await $0.applyStash(in: $1, ref: $2) }
    }

    /// Restore the stash and remove it from the stack.
    func pop(_ entry: StashEntry) async {
        await perform(entry) { try await $0.popStash(in: $1, ref: $2) }
    }

    /// Remove the stash without restoring it.
    func drop(_ entry: StashEntry) async {
        await perform(entry) { try await $0.dropStash(in: $1, ref: $2) }
    }

    private func perform(
        _ entry: StashEntry,
        _ operation: (StashProviding, URL, String) async throws -> Void
    ) async {
        guard let repositoryURL else { return }
        errorMessage = nil
        do {
            try await operation(stashProvider, repositoryURL, entry.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
