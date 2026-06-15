import Foundation

// Repository selection, launch bootstrap, and screen-data refresh.

@MainActor
extension RepositoryStoreViewModel {
    func selectRepository(at url: URL) async {
        let selectionGeneration = beginRepositorySelection(for: url)
        isLoading = true
        errorMessage = nil
        resetPerRepositoryState()

        do {
            let inspectedTip = try await inspector.inspectRepository(at: url)
            guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
            tip = inspectedTip
            _ = try await repositoryPersistence.saveOrUpdateRepository(path: url.path)
        } catch {
            guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
            tip = .unknown
            errorMessage = error.localizedDescription
        }

        guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
        await refreshRepositoryScreenData(for: Repository(url: url), selectionGeneration: selectionGeneration)
        guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
        await loadSavedRepositories()
        guard isCurrentRepositorySelection(url: url, generation: selectionGeneration) else { return }
        isLoading = false
    }

    func resetPerRepositoryState() {
        changedFileDiffTask?.cancel()
        changedFileDiffTask = nil
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
        diffHandler.clearSelection()
        historyHandler.clearSelection()
        changedFilesHandler.resetForRepositoryChange()
        commitForm.reset()
    }

    func bootstrapRepositorySelectionOnLaunch() async {
        await loadSavedRepositories()

        do {
            if let selected = try await repositoryPersistence.selectMostRecentlyOpenedRepositoryOnLaunch(),
               selected.existsOnDisk {
                await selectRepository(at: selected.url)
            }
        } catch {
            errorMessage = error.localizedDescription
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
        await refreshRepositoryScreenData(for: repository)
    }

    private func refreshRepositoryScreenData(
        for repository: Repository,
        selectionGeneration: Int? = nil
    ) async {
        do {
            let snapshot = try await screenRepository.loadSnapshot(for: repository)
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            primaryAction = snapshot.primaryAction
            remoteName = snapshot.remoteName
            forcePushNeeded = snapshot.forcePushNeeded
            changedFiles = snapshot.changedFiles
            commits = snapshot.commits
            canLoadMoreHistory = snapshot.commits.count >= HistoryPaging.pageSize
            unpushedSHAs = snapshot.unpushedSHAs
            currentGitUser = snapshot.userProfile

            changedFilesHandler.syncWith(changedFiles)

            if diffHandler.selectedFilePath == nil, let first = changedFiles.first?.path {
                diffHandler.selectFile(first)
            }

            if historyHandler.commitFiles.isEmpty, !commits.isEmpty {
                // Re-establish the anchor: keep it if it still exists, else default
                // to the newest commit. Loads that commit's files/diff.
                let anchor = historyHandler.anchorSHA
                let sha = (anchor.flatMap { a in commits.first(where: { $0.id == a })?.id }) ?? commits[0].id
                selectHistoryCommit(sha: sha)
            }

            await diffHandler.loadDiff(in: repository, changedFiles: changedFiles)
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            if let stashProvider {
                stashEntry = try? await stashProvider.fetchStash(in: repository.url)
                guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            } else {
                stashEntry = nil
            }
        } catch {
            guard isCurrentRepositoryRefreshTarget(repository, selectionGeneration: selectionGeneration) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func beginRepositorySelection(for url: URL) -> Int {
        repositorySelectionGeneration += 1
        selectedRepository = Repository(url: url)
        return repositorySelectionGeneration
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
}
