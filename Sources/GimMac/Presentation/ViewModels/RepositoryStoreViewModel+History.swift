import Foundation

// Commit-history selection, file/diff loading, and squash.

@MainActor
extension RepositoryStoreViewModel {
    func selectHistoryCommit(at index: Int, isShiftExtending: Bool = false) {
        historyHandler.selectCommit(at: index, extending: isShiftExtending)
        // When extending a range, the anchor commit's files are already loaded — skip reload.
        guard !isShiftExtending else { return }
        historyLoadTask?.cancel()
        guard let repository = selectedRepository,
              let sha = selectedCommit?.id else { return }
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

    func selectHistoryFile(path: String) {
        guard let repository = selectedRepository,
              let sha = selectedCommit?.id else { return }
        let provider = diffProvider
        let url = repository.url
        Task { [weak self] in
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
            historyHandler.selectCommit(at: 0)
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
            historyHandler.selectCommit(at: 0)
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
            historyHandler.selectCommit(at: 0)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
