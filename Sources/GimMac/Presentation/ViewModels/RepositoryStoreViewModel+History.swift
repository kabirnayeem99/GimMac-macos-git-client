import Foundation

// Commit-history selection, file/diff loading, and squash.

@MainActor
extension RepositoryStoreViewModel {
    /// Driven by the List's `Set<Commit.ID>` selection binding. SwiftUI handles
    /// shift/Cmd-click; we resolve the new anchor and load its files/diff.
    func updateHistorySelection(_ newSelection: Set<Commit.ID>) {
        guard let shaToLoad = historyHandler.applySelection(newSelection, in: commits) else { return }
        loadHistoryFiles(forSHA: shaToLoad)
    }

    /// Single-select a commit by SHA and load its files (used post-refresh).
    func selectHistoryCommit(sha: Commit.ID) {
        historyHandler.selectSingle(sha)
        loadHistoryFiles(forSHA: sha)
    }

    private func loadHistoryFiles(forSHA sha: Commit.ID) {
        historyLoadTask?.cancel()
        guard let repository = selectedRepository else { return }
        let inspector = commitInspector
        let provider = diffProvider
        let url = repository.url
        historyLoadTask = Task { [weak self] in
            guard let self else { return }
            await self.historyHandler.loadFiles(for: sha, using: inspector, in: url)
            guard !Task.isCancelled else { return }
            if let firstPath = self.historyHandler.selectedCommitFilePath {
                await self.historyHandler.loadDiff(
                    for: firstPath,
                    commitSHA: sha,
                    using: provider,
                    in: url
                )
            }
        }
    }

    /// Append the next page of commits when the user scrolls to the bottom.
    /// Re-entry-guarded; stops paging once a short (final) page comes back.
    func loadMoreHistory() async {
        guard canLoadMoreHistory, !isLoadingMoreHistory,
              let repository = selectedRepository else { return }

        isLoadingMoreHistory = true
        defer { isLoadingMoreHistory = false }

        do {
            let more = try await screenRepository.loadMoreCommits(
                for: repository,
                skip: commits.count,
                maxCount: HistoryPaging.pageSize
            )
            // A concurrent refresh may have rebuilt `commits` while we paged;
            // drop any overlap so SHAs stay unique (List identity is the SHA).
            let existing = Set(commits.map(\.id))
            let fresh = more.filter { !existing.contains($0.id) }
            commits.append(contentsOf: fresh)
            canLoadMoreHistory = more.count >= HistoryPaging.pageSize
        } catch {
            errorMessage = error.localizedDescription
            canLoadMoreHistory = false
        }
    }

    func selectHistoryFile(path: String) {
        guard let repository = selectedRepository,
              let sha = selectedCommit?.id else { return }
        let provider = diffProvider
        let url = repository.url
        historyFileDiffTask?.cancel()
        historyFileDiffTask = Task { [weak self] in
            await self?.historyHandler.loadDiff(
                for: path,
                commitSHA: sha,
                using: provider,
                in: url
            )
        }
    }

    func squashSelectedCommits(message: String) async {
        guard let repository = selectedRepository,
              let squashProvider,
              selectedHistoryCommits.count >= 2 else { return }

        let commitsToSquash = selectedHistoryCommits
        isSquashing = true
        errorMessage = nil
        defer { isSquashing = false }

        do {
            try await squashProvider.squash(commits: commitsToSquash, message: message, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revertSelectedCommit() async {
        guard let repository = selectedRepository,
              let revertProvider,
              let commit = selectedCommit else { return }

        isReverting = true
        errorMessage = nil
        defer { isReverting = false }

        do {
            try await revertProvider.revert(commit: commit, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cherryPickSelectedCommits() async {
        guard let repository = selectedRepository,
              let cherryPickProvider,
              !selectedHistoryCommits.isEmpty else { return }

        let commitsToPick = selectedHistoryCommits
        isCherryPicking = true
        errorMessage = nil
        defer { isCherryPicking = false }

        do {
            try await cherryPickProvider.cherryPick(commits: commitsToPick, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTagOnSelectedCommit(named name: String, message: String?) async {
        guard let repository = selectedRepository,
              let tagProvider,
              let commit = selectedCommit else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isTagging = true
        errorMessage = nil
        defer { isTagging = false }

        do {
            try await tagProvider.createTag(named: trimmedName, message: message, at: commit, in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createBranchFromSelectedCommit(named name: String) async {
        guard let repository = selectedRepository,
              let branchOperator,
              let commit = selectedCommit else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreatingBranchFromCommit = true
        errorMessage = nil
        defer { isCreatingBranchFromCommit = false }

        do {
            try await branchOperator.createBranch(
                named: trimmedName,
                from: .commit(sha: commit.id),
                noTrack: false,
                in: repository.url
            )
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetToSelectedCommit(mode: ResetMode) async {
        guard let repository = selectedRepository,
              let resetProvider,
              let commit = selectedCommit else { return }

        isResetting = true
        errorMessage = nil
        defer { isResetting = false }

        do {
            try await resetProvider.reset(to: commit, mode: mode, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reorderCommits(_ orderedCommits: [Commit]) async {
        guard let repository = selectedRepository,
              let reorderProvider,
              orderedCommits.count >= 2 else { return }

        isReordering = true
        errorMessage = nil
        defer { isReordering = false }

        do {
            try await reorderProvider.reorder(orderedCommits: orderedCommits, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
