import Foundation

// Repository selection, launch bootstrap, and screen-data refresh.

@MainActor
extension RepositoryStoreViewModel {
    func selectRepository(at url: URL) async {
        isLoading = true
        errorMessage = nil
        selectedRepository = Repository(url: url)
        resetPerRepositoryState()
        defer { isLoading = false }

        do {
            tip = try await inspector.inspectRepository(at: url)
            _ = try await repositoryPersistence.saveOrUpdateRepository(path: url.path)
        } catch {
            tip = .unknown
            errorMessage = error.localizedDescription
        }

        await refreshRepositoryScreenData()
        await loadSavedRepositories()
    }

    func resetPerRepositoryState() {
        historyLoadTask?.cancel()
        historyLoadTask = nil
        changedFiles = []
        commits = []
        unpushedSHAs = []
        tip = .unknown
        primaryAction = .publishRepository
        remoteName = nil
        forcePushNeeded = false
        lastFetched = nil
        stashEntry = nil
        errorMessage = nil
        diffHandler.clearSelection()
        historyHandler.selectCommit(at: 0)
        changedFilesHandler.deselectAll()
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
        do {
            let snapshot = try await screenRepository.loadSnapshot(for: selectedRepository)
            primaryAction = snapshot.primaryAction
            remoteName = snapshot.remoteName
            forcePushNeeded = snapshot.forcePushNeeded
            changedFiles = snapshot.changedFiles
            commits = snapshot.commits
            unpushedSHAs = snapshot.unpushedSHAs
            currentGitUser = snapshot.userProfile

            changedFilesHandler.syncWith(changedFiles)

            if diffHandler.selectedFilePath == nil, let first = changedFiles.first?.path {
                diffHandler.selectFile(first)
            }

            if historyHandler.commitFiles.isEmpty, !commits.isEmpty {
                selectHistoryCommit(at: historyHandler.selectedIndex)
            }

            if let repository = selectedRepository {
                await diffHandler.loadDiff(in: repository, changedFiles: changedFiles)
                if let stashProvider {
                    stashEntry = try? await stashProvider.fetchStash(in: repository.url)
                } else {
                    stashEntry = nil
                }
            } else {
                stashEntry = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
