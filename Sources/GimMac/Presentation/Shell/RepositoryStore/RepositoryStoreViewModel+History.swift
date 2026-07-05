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
        logger.info(
            "History commit selection requested",
            category: .history,
            metadata: ["commit": sha, "commits": String(commits.count)]
        )
        historyHandler.selectSingle(sha)
        loadHistoryFiles(forSHA: sha)
    }

    private func loadHistoryFiles(forSHA sha: Commit.ID) {
        let isInitialHistoryFilesLoad = historyHandler.commitFiles.isEmpty
        historyLoadTask?.cancel()
        historyFileDiffTask?.cancel()
        historyFileDiffTask = nil
        guard let repository = selectedRepository else { return }
        let inspector = commitInspector
        let provider = diffProvider
        let url = repository.url
        let tag = logger.tag("history.files-load", parent: nil, metadata: [
            "repository": url.lastPathComponent,
            "commit": sha,
            "initial_load": String(isInitialHistoryFilesLoad)
        ])
        logger.info(
            isInitialHistoryFilesLoad ? "Initial history files load scheduled" : "History files load scheduled",
            category: .history,
            metadata: [
                "repository": url.lastPathComponent,
                "commit": sha,
                "initial_load": String(isInitialHistoryFilesLoad)
            ],
            tag: tag
        )
        historyLoadTask = Task { [weak self] in
            guard let self else { return }
            let filesStartedAt = Self.nowMilliseconds()
            logger.info(
                isInitialHistoryFilesLoad ? "Initial history files load started" : "History files load started",
                category: .history,
                metadata: ["repository": url.lastPathComponent, "commit": sha],
                tag: tag
            )
            await self.historyHandler.loadFiles(for: sha, using: inspector, in: url)
            guard !Task.isCancelled else {
                logger.warning(
                    "History files load cancelled",
                    category: .history,
                    metadata: [
                        "repository": url.lastPathComponent,
                        "commit": sha,
                        "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: filesStartedAt))
                    ],
                    tag: tag
                )
                return
            }
            logger.info(
                isInitialHistoryFilesLoad ? "Initial history files load finished" : "History files load finished",
                category: .history,
                metadata: [
                    "repository": url.lastPathComponent,
                    "commit": sha,
                    "files": String(self.historyHandler.commitFiles.count),
                    "selected_path": self.historyHandler.selectedCommitFilePath ?? "",
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: filesStartedAt))
                ],
                tag: tag
            )
            if let firstPath = self.historyHandler.selectedCommitFilePath {
                let diffStartedAt = Self.nowMilliseconds()
                logger.info(
                    isInitialHistoryFilesLoad ? "Initial history diff load started" : "History diff load started",
                    category: .history,
                    metadata: ["repository": url.lastPathComponent, "commit": sha, "path": firstPath],
                    tag: tag
                )
                await self.historyHandler.loadDiff(
                    for: firstPath,
                    commitSHA: sha,
                    using: provider,
                    in: url
                )
                guard !Task.isCancelled else {
                    logger.warning(
                        "History diff load cancelled",
                        category: .history,
                        metadata: [
                            "repository": url.lastPathComponent,
                            "commit": sha,
                            "path": firstPath,
                            "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: diffStartedAt))
                        ],
                        tag: tag
                    )
                    return
                }
                logger.info(
                    isInitialHistoryFilesLoad ? "Initial history diff load finished" : "History diff load finished",
                    category: .history,
                    metadata: [
                        "repository": url.lastPathComponent,
                        "commit": sha,
                        "path": firstPath,
                        "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: diffStartedAt))
                    ],
                    tag: tag
                )
            } else {
                logger.info(
                    "History files load produced no selectable diff",
                    category: .history,
                    metadata: ["repository": url.lastPathComponent, "commit": sha],
                    tag: tag
                )
            }
        }
    }

    /// Append the next page of commits when the user scrolls to the bottom.
    /// Re-entry-guarded; stops paging once a short (final) page comes back.
    func loadMoreHistory() async {
        guard canLoadMoreHistory, !isLoadingMoreHistory,
              let repository = selectedRepository else { return }

        let tag = logger.tag("history.load-more", parent: nil, metadata: [
            "repository": repository.url.lastPathComponent,
            "skip": String(commits.count),
            "page_size": String(HistoryPaging.pageSize)
        ])
        let startedAt = Self.nowMilliseconds()
        logger.info(
            "History page load started",
            category: .history,
            metadata: [
                "repository": repository.url.lastPathComponent,
                "skip": String(commits.count),
                "page_size": String(HistoryPaging.pageSize)
            ],
            tag: tag
        )
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
            logger.info(
                "History page load finished",
                category: .history,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "received": String(more.count),
                    "appended": String(fresh.count),
                    "total": String(commits.count),
                    "can_load_more": String(canLoadMoreHistory),
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
        } catch {
            errorMessage = error.localizedDescription
            canLoadMoreHistory = false
            logger.error(
                "History page load failed",
                category: .history,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "reason": error.localizedDescription,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
        }
    }

    func selectHistoryFile(path: String) {
        guard let repository = selectedRepository,
              let sha = selectedCommit?.id else { return }
        let provider = diffProvider
        let url = repository.url
        historyFileDiffTask?.cancel()
        let tag = logger.tag("history.file-diff-load", parent: nil, metadata: [
            "repository": url.lastPathComponent,
            "commit": sha,
            "path": path
        ])
        logger.info(
            "History file diff load scheduled",
            category: .history,
            metadata: ["repository": url.lastPathComponent, "commit": sha, "path": path],
            tag: tag
        )
        historyFileDiffTask = Task { [weak self] in
            let startedAt = Self.nowMilliseconds()
            self?.logger.info(
                "History file diff load started",
                category: .history,
                metadata: ["repository": url.lastPathComponent, "commit": sha, "path": path],
                tag: tag
            )
            await self?.historyHandler.loadDiff(
                for: path,
                commitSHA: sha,
                using: provider,
                in: url
            )
            guard !Task.isCancelled else {
                self?.logger.warning(
                    "History file diff load cancelled",
                    category: .history,
                    metadata: [
                        "repository": url.lastPathComponent,
                        "commit": sha,
                        "path": path,
                        "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                    ],
                    tag: tag
                )
                return
            }
            self?.logger.info(
                "History file diff load finished",
                category: .history,
                metadata: [
                    "repository": url.lastPathComponent,
                    "commit": sha,
                    "path": path,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
        }
    }

    func squashSelectedCommits(message: String) async -> Bool {
        guard let repository = selectedRepository,
              let squashProvider,
              selectedHistoryCommits.count >= 2 else { return false }

        let commitsToSquash = selectedHistoryCommits
        isSquashing = true
        errorMessage = nil
        defer { isSquashing = false }

        do {
            try await squashProvider.squash(commits: commitsToSquash, message: message, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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

    func createTagOnSelectedCommit(named name: String, message: String?) async -> Bool {
        guard let repository = selectedRepository,
              let tagProvider,
              let commit = selectedCommit else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        isTagging = true
        errorMessage = nil
        defer { isTagging = false }

        do {
            try await tagProvider.createTag(named: trimmedName, message: message, at: commit, in: repository.url)
            await refreshRepositoryScreenData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func createBranchFromSelectedCommit(named name: String) async -> Bool {
        guard let repository = selectedRepository,
              let branchOperator,
              let commit = selectedCommit else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

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
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resetToSelectedCommit(mode: ResetMode) async -> Bool {
        guard let repository = selectedRepository,
              let resetProvider,
              let commit = selectedCommit else { return false }

        isResetting = true
        errorMessage = nil
        defer { isResetting = false }

        do {
            try await resetProvider.reset(to: commit, mode: mode, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func reorderCommits(_ orderedCommits: [Commit]) async -> Bool {
        guard let repository = selectedRepository,
              let reorderProvider,
              orderedCommits.count >= 2 else { return false }

        isReordering = true
        errorMessage = nil
        defer { isReordering = false }

        do {
            try await reorderProvider.reorder(orderedCommits: orderedCommits, in: repository.url)
            historyHandler.clearSelection()
            await refreshRepositoryScreenData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
