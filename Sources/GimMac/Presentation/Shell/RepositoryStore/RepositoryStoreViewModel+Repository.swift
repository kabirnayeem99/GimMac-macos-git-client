import Foundation

// Repository selection, launch bootstrap, and screen-data refresh.

@MainActor
extension RepositoryStoreViewModel {
    func selectRepository(at url: URL) async {
        if isLoadedOrLoadingSelectedRepository(url) {
            return
        }

        let selectionGeneration = beginRepositorySelection(for: url)
        let selectionTag = logger.tag("repository.select", parent: nil, metadata: [
            "repository": url.lastPathComponent,
            "path": url.path,
            "generation": String(selectionGeneration)
        ])
        logger.info(
            "Repository selection started",
            category: .repository,
            metadata: ["repository": url.lastPathComponent, "generation": String(selectionGeneration)],
            tag: selectionTag
        )
        isLoading = true
        errorMessage = nil
        resetPerRepositoryState()

        do {
            let inspectStartedAt = Self.nowMilliseconds()
            let inspection = try await inspector.inspectRepository(at: url)
            guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
            logger.info(
                "Repository inspection finished",
                category: .repository,
                metadata: [
                    "repository": url.lastPathComponent,
                    "generation": String(selectionGeneration),
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: inspectStartedAt)),
                    "inspection_cache_available": "true"
                ],
                tag: selectionTag
            )
            currentInspection = inspection
            tip = inspection.tip
            _ = try await repositoryPersistence.saveOrUpdateRepository(path: url.path)
        } catch {
            guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
            tip = .unknown
            errorMessage = error.localizedDescription
            logger.error(
                "Repository selection failed",
                category: .repository,
                metadata: [
                    "repository": url.lastPathComponent,
                    "generation": String(selectionGeneration),
                    "reason": error.localizedDescription
                ],
                tag: selectionTag
            )
        }

        guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
        await refreshRepositoryScreenData(
            for: Repository(url: url),
            selectionGeneration: selectionGeneration,
            inspection: currentInspection,
            parentTag: selectionTag
        )
        guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
        await loadSavedRepositories()
        guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
        isLoading = false
        logger.info(
            "Repository selection finished",
            category: .repository,
            metadata: ["repository": url.lastPathComponent, "generation": String(selectionGeneration)],
            tag: selectionTag
        )
    }

    func resetPerRepositoryState() {
        changedFileDiffTask?.cancel()
        changedFileDiffTask = nil
        secondaryRefreshTask?.cancel()
        secondaryRefreshTask = nil
        currentInspection = nil
        historyLoadTask?.cancel()
        historyLoadTask = nil
        historyFileDiffTask?.cancel()
        historyFileDiffTask = nil
        changedFiles = []
        commits = []
        canLoadMoreHistory = false
        unpushedSHAs = []
        tip = .unknown
        primaryAction = .publishRepository
        remoteName = nil
        forcePushNeeded = false
        resetOperationOutcomes()
        lastFetched = nil
        stashEntry = nil
        errorMessage = nil
        isResolvingConflicts = false
        conflictedFiles = []
        initialConflictCount = 0
        conflictMergeToolName = nil
        isConflictActionInProgress = false
        diffHandler.clearSelection()
        diffHandler.clearCache()
        historyHandler.clearSelection()
        changedFilesHandler.resetForRepositoryChange()
        commitForm.reset()
    }

    func bootstrapRepositorySelectionOnLaunch() async {
        let bootstrapTag = logger.tag("repository.launch-bootstrap", parent: nil, metadata: [:])
        logger.info("Launch repository bootstrap started", category: .repository, metadata: [:], tag: bootstrapTag)
        await loadSavedRepositories()

        do {
            if let selected = try await repositoryPersistence.selectMostRecentlyOpenedRepositoryOnLaunch(),
               selected.existsOnDisk {
                logger.info(
                    "Launch repository bootstrap selected repository",
                    category: .repository,
                    metadata: ["repository": selected.url.lastPathComponent, "path": selected.url.path],
                    tag: bootstrapTag
                )
                await selectRepository(at: selected.url)
            }
        } catch {
            errorMessage = error.localizedDescription
            logger.error(
                "Launch repository bootstrap failed",
                category: .repository,
                metadata: ["reason": error.localizedDescription],
                tag: bootstrapTag
            )
        }
    }

    func selectPersistedRepository(id: UUID) async {
        do {
            guard let selected = try await repositoryPersistence.selectRepository(id: id) else { return }
            if !selected.existsOnDisk {
                await loadSavedRepositories()
                return
            }
            await selectRepository(at: selected.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSavedRepositories() async {
        do {
            savedRepositories = try await repositoryPersistence.getAllRepositoriesSortedByLastOpened()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRepositoryScreenData() async {
        guard let repository = selectedRepository else {
            stashEntry = nil
            return
        }
        await refreshRepositoryScreenData(for: repository, inspection: currentInspection)
    }

    private func refreshRepositoryScreenData(
        for repository: Repository,
        selectionGeneration: Int? = nil,
        inspection: RepositoryInspectionResult? = nil,
        parentTag: LogFlowTag? = nil
    ) async {
        let refreshStartedAt = Self.nowMilliseconds()
        let isInitialChangedFilesLoad = !changedFilesHandler.hasLoadedOnce
        let refreshTag = logger.tag("repository.screen-data-refresh", parent: parentTag, metadata: [
            "repository": repository.url.lastPathComponent,
            "path": repository.url.path,
            "generation": selectionGeneration.map(String.init) ?? "manual",
            "initial_changed_files_load": String(isInitialChangedFilesLoad)
        ])
        logger.info(
            "Repository screen data refresh started",
            category: .repository,
            metadata: [
                "repository": repository.url.lastPathComponent,
                "generation": selectionGeneration.map(String.init) ?? "manual",
                "initial_changed_files_load": String(isInitialChangedFilesLoad)
            ],
            tag: refreshTag
        )

        do {
            let snapshotStartedAt = Self.nowMilliseconds()
            let snapshot = try await screenRepository.loadCriticalSnapshot(for: repository, inspection: inspection)
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            logger.info(
                "Repository critical snapshot loaded",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "changed_files": String(snapshot.changedFiles.count),
                    "commits": String(snapshot.commits.count),
                    "unpushed": String(snapshot.unpushedSHAs.count),
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: snapshotStartedAt)),
                    "inspection_cache_used": String(inspection != nil)
                ],
                tag: refreshTag
            )
            primaryAction = snapshot.primaryAction
            remoteName = snapshot.remoteName
            forcePushNeeded = snapshot.forcePushNeeded
            changedFiles = snapshot.changedFiles
            commits = snapshot.commits
            canLoadMoreHistory = snapshot.commits.count >= HistoryPaging.pageSize
            unpushedSHAs = snapshot.unpushedSHAs
            currentGitUser = snapshot.userProfile

            logger.debug(
                "Changed files sync started",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "changed_files": String(changedFiles.count),
                    "initial_load": String(isInitialChangedFilesLoad)
                ],
                tag: refreshTag
            )
            let changedFilesSyncStartedAt = Self.nowMilliseconds()
            changedFilesHandler.syncWith(changedFiles)
            logger.info(
                isInitialChangedFilesLoad ? "Initial changed files synced" : "Changed files synced",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "changed_files": String(changedFiles.count),
                    "checked_files": String(changedFilesHandler.checkedPaths.count),
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: changedFilesSyncStartedAt))
                ],
                tag: refreshTag
            )

            if diffHandler.selectedFilePath == nil, let first = changedFiles.first?.path {
                diffHandler.selectFile(first)
                logger.info(
                    "Initial changed file selected",
                    category: .diff,
                    metadata: ["repository": repository.url.lastPathComponent, "path": first],
                    tag: refreshTag
                )
            }

            if historyHandler.commitFiles.isEmpty, !commits.isEmpty {
                // Re-establish the anchor: keep it if it still exists, else default
                // to the newest commit. Loads that commit's files/diff.
                let anchor = historyHandler.anchorSHA
                let sha = (anchor.flatMap { a in commits.first(where: { $0.id == a })?.id }) ?? commits[0].id
                logger.info(
                    "Initial history commit selected",
                    category: .history,
                    metadata: [
                        "repository": repository.url.lastPathComponent,
                        "commit": sha,
                        "commits": String(commits.count)
                    ],
                    tag: refreshTag
                )
                selectHistoryCommit(sha: sha)
            }

            let diffStartedAt = Self.nowMilliseconds()
            logger.info(
                isInitialChangedFilesLoad ? "Initial changed file diff load started" : "Changed file diff load started",
                category: .diff,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "selected_path": diffHandler.selectedFilePath ?? "",
                    "changed_files": String(changedFiles.count)
                ],
                tag: refreshTag
            )
            await diffHandler.loadDiff(in: repository, changedFiles: changedFiles, inspection: inspection)
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            logger.info(
                isInitialChangedFilesLoad ? "Initial changed file diff load finished" : "Changed file diff load finished",
                category: .diff,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "selected_path": diffHandler.selectedFilePath ?? "",
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: diffStartedAt))
                ],
                tag: refreshTag
            )
            logger.info(
                "Repository critical refresh finished",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: refreshStartedAt))
                ],
                tag: refreshTag
            )
            startSecondaryRepositoryRefresh(
                repository: repository,
                selectionGeneration: selectionGeneration,
                inspection: inspection,
                criticalSnapshot: snapshot,
                parentTag: refreshTag
            )
        } catch {
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            errorMessage = error.localizedDescription
            logger.error(
                "Repository screen data refresh failed",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "reason": error.localizedDescription,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: refreshStartedAt))
                ],
                tag: refreshTag
            )
        }
    }

    private func startSecondaryRepositoryRefresh(
        repository: Repository,
        selectionGeneration: Int?,
        inspection: RepositoryInspectionResult?,
        criticalSnapshot: CriticalRepositorySnapshot,
        parentTag: LogFlowTag?
    ) {
        secondaryRefreshTask?.cancel()
        secondaryRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.loadSecondaryRepositoryData(
                repository: repository,
                selectionGeneration: selectionGeneration,
                inspection: inspection,
                criticalSnapshot: criticalSnapshot,
                parentTag: parentTag
            )
        }
    }

    private func loadSecondaryRepositoryData(
        repository: Repository,
        selectionGeneration: Int?,
        inspection: RepositoryInspectionResult?,
        criticalSnapshot: CriticalRepositorySnapshot,
        parentTag: LogFlowTag?
    ) async {
        let startedAt = Self.nowMilliseconds()
        let tag = logger.tag("repository.secondary-refresh", parent: parentTag, metadata: [
            "repository": repository.url.lastPathComponent,
            "generation": selectionGeneration.map(String.init) ?? "manual"
        ])
        logger.info(
            "Repository secondary refresh started",
            category: .repository,
            metadata: ["repository": repository.url.lastPathComponent],
            tag: tag
        )

        do {
            let secondary = try await screenRepository.loadSecondarySnapshot(
                for: repository,
                inspection: inspection,
                criticalSnapshot: criticalSnapshot
            )
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            primaryAction = secondary.primaryAction
            remoteName = secondary.remoteName
            forcePushNeeded = secondary.forcePushNeeded
            unpushedSHAs = secondary.unpushedSHAs
            currentGitUser = secondary.userProfile
            if let stashProvider {
                stashEntry = try? await stashProvider.fetchStash(in: repository.url)
                guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            } else {
                stashEntry = nil
            }
            logger.info(
                "Repository secondary refresh finished",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "remote": secondary.remoteName ?? "",
                    "unpushed": String(secondary.unpushedSHAs.count),
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
        } catch {
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            logger.error(
                "Repository secondary refresh failed",
                category: .repository,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "reason": error.localizedDescription,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
        }
    }

    private func beginRepositorySelection(for url: URL) -> Int {
        repositorySelectionGeneration += 1
        selectedRepository = Repository(url: url)
        return repositorySelectionGeneration
    }

    private func isLoadedOrLoadingSelectedRepository(_ url: URL) -> Bool {
        guard let selectedRepository else { return false }
        return Self.canonicalRepositoryPath(selectedRepository.url) == Self.canonicalRepositoryPath(url) &&
            (isLoading || tip != .unknown)
    }

    private static func canonicalRepositoryPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func isCurrentRepositorySelection(url: URL, generation: Int) -> Bool {
        repositorySelectionGeneration == generation && selectedRepository?.url == url
    }

    private func isCurrentRepositoryRefreshTarget(
        _ repository: Repository,
        selectionGeneration: Int?
    ) -> Bool {
        selectedRepository?.url == repository.url &&
            (selectionGeneration == nil || repositorySelectionGeneration == selectionGeneration)
    }

    static func nowMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }

    static func elapsedMilliseconds(since startedAt: Double) -> Double {
        max(0, nowMilliseconds() - startedAt)
    }

    static func formatMilliseconds(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
    }
}
