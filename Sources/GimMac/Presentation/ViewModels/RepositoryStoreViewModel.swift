import Foundation
import Observation

@MainActor
@Observable
final class RepositoryStoreViewModel {
    private let inspector: RepositoryInspecting
    private let screenRepository: RepositoryScreenDataProviding
    private let commitProvider: CommitProviding
    private let repositoryPersistence: RepositoryPersistenceProviding

    let commitForm = CommitFormHandler()
    let changedFilesHandler = ChangedFilesHandler()
    let diffHandler: DiffHandler
    let historyHandler = HistoryHandler()

    private(set) var selectedRepository: Repository?
    private(set) var tip: TipState = .unknown
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private(set) var primaryAction: RepositoryPrimaryAction = .publishRepository
    private(set) var remoteName: String?
    private(set) var lastFetched: Date?
    private(set) var forcePushNeeded = false
    private(set) var changedFiles: [ChangedFile] = []
    private(set) var commits: [Commit] = []
    private(set) var currentGitUser = GitUserProfile(name: "Unknown User", email: "unknown@example.com")
    private(set) var savedRepositories: [StoredRepository] = []

    // MARK: - Forwarded from handlers (views bind through these)

    var commitSummary: String {
        get { commitForm.commitSummary }
        set { commitForm.commitSummary = newValue }
    }

    var commitDescription: String {
        get { commitForm.commitDescription }
        set { commitForm.commitDescription = newValue }
    }

    var isCommitting: Bool { commitForm.isCommitting }
    var selectedHistoryCommitIndex: Int { historyHandler.selectedIndex }
    var selectedChangedFilePath: String? { diffHandler.selectedFilePath }
    var checkedChangedFilePaths: Set<String> { changedFilesHandler.checkedPaths }
    var selectedDiffDocument: DiffDocument { diffHandler.selectedDiffDocument }
    var isLoadingDiff: Bool { diffHandler.isLoadingDiff }

    // MARK: - Computed

    var changedFilesCount: Int { changedFiles.count }

    var selectedCommit: Commit? { historyHandler.selectedCommit(in: commits) }

    var commitButtonLabel: String { primaryAction.label }

    var lastCommitSectionTitle: String {
        selectedCommit == nil ? "No commits yet" : "Committed just now"
    }

    var lastCommitSummary: String {
        selectedCommit?.summary ?? "No recent commit"
    }

    var lastFetchedDescription: String {
        guard let date = lastFetched else { return "Never fetched" }
        return "Last fetched " + RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    var canCommitChanges: Bool {
        !commitForm.isCommitting &&
        selectedRepository != nil &&
        !changedFilesHandler.checkedPaths.isEmpty &&
        !commitForm.trimmedSummary.isEmpty
    }

    // MARK: - Init

    init(
        inspector: RepositoryInspecting,
        screenRepository: RepositoryScreenDataProviding,
        diffProvider: DiffProviding,
        commitProvider: CommitProviding,
        repositoryPersistence: RepositoryPersistenceProviding
    ) {
        self.inspector = inspector
        self.screenRepository = screenRepository
        self.commitProvider = commitProvider
        self.repositoryPersistence = repositoryPersistence
        self.diffHandler = DiffHandler(diffProvider: diffProvider)
    }

    // MARK: - Repository selection

    func selectRepository(at url: URL) async {
        isLoading = true
        errorMessage = nil
        selectedRepository = Repository(url: url)
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
            currentGitUser = snapshot.userProfile

            changedFilesHandler.syncWith(changedFiles)

            if diffHandler.selectedFilePath == nil, let first = changedFiles.first?.path {
                diffHandler.selectFile(first)
            }

            if let commit = selectedCommit {
                commitForm.prefill(summary: commit.summary, body: commit.body)
            }

            if let repository = selectedRepository {
                await diffHandler.loadDiff(in: repository, changedFiles: changedFiles)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delegated to handlers

    func selectHistoryCommit(at index: Int) {
        historyHandler.selectCommit(at: index)
    }

    func selectChangedFile(path: String) {
        diffHandler.selectFile(path)
        guard let repository = selectedRepository else { return }
        Task { [weak self] in
            await self?.diffHandler.loadDiff(in: repository, changedFiles: self?.changedFiles ?? [])
        }
    }

    func isChangedFileChecked(path: String) -> Bool {
        changedFilesHandler.isChecked(path)
    }

    func toggleChangedFileChecked(path: String) {
        changedFilesHandler.toggle(path)
    }

    // MARK: - Commit

    func commitChanges() async {
        guard canCommitChanges, let repository = selectedRepository else { return }

        let summary = commitForm.trimmedSummary
        let description = commitForm.trimmedDescription
        let pathsToCommit = changedFilesHandler.checkedPaths.sorted()

        commitForm.setCommitting(true)
        errorMessage = nil
        defer { commitForm.setCommitting(false) }

        do {
            try await commitProvider.commit(
                in: repository.url,
                paths: pathsToCommit,
                summary: summary,
                description: description.isEmpty ? nil : description
            )
            commitForm.reset()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
