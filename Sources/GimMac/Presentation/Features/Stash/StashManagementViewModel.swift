import Foundation
import Observation

/// Drives the Stash Management sheet: lists every stash and exposes
/// apply / pop / drop on a selected entry. Native equivalent of the stash
/// surface in GitHub Desktop's Changes tab, generalized to the full stack.
@MainActor
@Observable
final class StashManagementViewModel {
    enum Action: Equatable {
        case apply
        case pop
        case drop
    }

    private(set) var stashes: [StashEntry] = []
    private(set) var isLoading = false
    private(set) var activeAction: Action?
    private(set) var completedAction: Action?
    var errorMessage: String?

    var repositoryURL: URL? {
        didSet {
            guard oldValue != repositoryURL else { return }
            repositoryGeneration += 1
        }
    }

    private let stashProvider: StashProviding
    private var completedActionResetTask: Task<Void, Never>?
    private var repositoryGeneration: Int = 0

    init(stashProvider: StashProviding) {
        self.stashProvider = stashProvider
    }

    func load() async {
        guard let repositoryURL, !isLoading else { return }
        let generation = repositoryGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if isCurrentRepositoryTarget(repositoryURL, generation: generation) {
                isLoading = false
            }
        }
        do {
            let fetched = try await stashProvider.fetchAllStashes(in: repositoryURL)
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            stashes = fetched
        } catch {
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func isCurrentRepositoryTarget(_ url: URL, generation: Int) -> Bool {
        repositoryGeneration == generation && repositoryURL == url
    }

    /// Restore the stash, keeping it in the stack.
    func apply(_ entry: StashEntry) async {
        await perform(.apply, entry) { try await $0.applyStash(in: $1, ref: $2) }
    }

    /// Restore the stash and remove it from the stack.
    func pop(_ entry: StashEntry) async {
        await perform(.pop, entry) { try await $0.popStash(in: $1, ref: $2) }
    }

    /// Remove the stash without restoring it.
    func drop(_ entry: StashEntry) async {
        await perform(.drop, entry) { try await $0.dropStash(in: $1, ref: $2) }
    }

    private func perform(
        _ action: Action,
        _ entry: StashEntry,
        _ operation: (StashProviding, URL, String) async throws -> Void
    ) async {
        guard let repositoryURL, activeAction == nil else { return }
        let generation = repositoryGeneration
        activeAction = action
        completedActionResetTask?.cancel()
        completedAction = nil
        errorMessage = nil
        defer {
            if isCurrentRepositoryTarget(repositoryURL, generation: generation) {
                activeAction = nil
            }
        }
        do {
            try await operation(stashProvider, repositoryURL, entry.id)
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            completedAction = action
            completedActionResetTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.0))
                self?.completedAction = nil
            }
            await load()
        } catch {
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
