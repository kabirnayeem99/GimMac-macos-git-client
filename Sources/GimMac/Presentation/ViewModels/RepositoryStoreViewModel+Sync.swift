import Foundation

// Remote sync: primary action dispatch, force push, explicit fetch / pull.

@MainActor
extension RepositoryStoreViewModel {
    func performPrimaryAction() async {
        guard canPerformPrimaryAction,
              let provider = remoteSyncProvider,
              let repository = selectedRepository else { return }

        isSyncInProgress = true
        errorMessage = nil
        defer { isSyncInProgress = false }

        do {
            switch primaryAction {
            case .fetch(let remote):
                try await provider.fetch(remote: remote, in: repository.url)
                lastFetched = Date()

            case .pull:
                try await provider.pull(in: repository.url)
                lastFetched = Date()

            case .push(let remote, _):
                try await provider.push(remote: remote, in: repository.url)

            case .forcePush(let remote, _):
                try await provider.pushForceSafely(remote: remote, in: repository.url)

            case .sync(let remote, _, _):
                try await provider.pull(in: repository.url)
                try await provider.push(remote: remote, in: repository.url)
                lastFetched = Date()

            case .publishBranch(let remote):
                guard case .valid(let summary) = tip else { return }
                try await provider.publishBranch(named: summary.name, remote: remote, in: repository.url)

            case .merge, .rebase, .cherryPick:
                // Mid-conflict: the primary button ("Continue Merge/Rebase/
                // Cherry-Pick") opens the conflict resolution sheet.
                isSyncInProgress = false
                await beginConflictResolution()
                return

            case .publishRepository, .commit:
                return
            }

            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performForcePush() async {
        guard let provider = remoteSyncProvider,
              let remote = remoteName,
              let repository = selectedRepository,
              !isSyncInProgress else { return }

        isSyncInProgress = true
        errorMessage = nil
        defer { isSyncInProgress = false }

        do {
            try await provider.pushForceSafely(remote: remote, in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Explicit fetch — drives the File/Repository → Fetch menu item.
    /// Falls back to "origin" when no upstream remote has been resolved yet.
    func fetch() async {
        guard let provider = remoteSyncProvider,
              let repository = selectedRepository,
              !isSyncInProgress else { return }

        let remote = remoteName ?? "origin"
        isSyncInProgress = true
        errorMessage = nil
        defer { isSyncInProgress = false }

        do {
            try await provider.fetch(remote: remote, in: repository.url)
            lastFetched = Date()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Explicit pull — drives the Repository → Pull menu item.
    func pull() async {
        guard let provider = remoteSyncProvider,
              let repository = selectedRepository,
              !isSyncInProgress else { return }

        isSyncInProgress = true
        errorMessage = nil
        defer { isSyncInProgress = false }

        do {
            try await provider.pull(in: repository.url)
            lastFetched = Date()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
