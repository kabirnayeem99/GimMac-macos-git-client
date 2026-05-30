import AppKit
import Foundation
import Observation

// Architecture note: AppKit is imported here only for `NSWorkspace` used to
// reveal a file in Finder. This is a small, native-only OS integration that
// avoids creating a separate service for a single one-line side effect.

@MainActor
@Observable
final class RepositoryStoreViewModel {
    private let inspector: RepositoryInspecting
    private let screenRepository: RepositoryScreenDataProviding
    private let diffProvider: DiffProviding
    private let commitInspector: CommitInspecting
    private let commitProvider: CommitProviding
    private let repositoryPersistence: RepositoryPersistenceProviding
    private let discardProvider: DiscardProviding?
    private let stashProvider: StashProviding?
    private let branchProvider: BranchProviding?
    private let branchOperator: BranchOperating?
    private let statusProvider: StatusProviding?

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
    var isAmendMode: Bool { commitForm.isAmendMode }
    var summaryCharacterCount: Int { commitForm.summaryCharacterCount }
    var summaryExceedsRecommendedLength: Bool { commitForm.summaryExceedsRecommendedLength }

    var skipHooks: Bool {
        get { commitForm.skipHooks }
        set { commitForm.skipHooks = newValue }
    }
    var signOff: Bool {
        get { commitForm.signOff }
        set { commitForm.signOff = newValue }
    }
    var selectedHistoryCommitIndex: Int { historyHandler.selectedIndex }
    var historyFiles: [CommitFile] { historyHandler.commitFiles }
    var isLoadingHistoryFiles: Bool { historyHandler.isLoadingCommitFiles }
    var selectedHistoryFilePath: String? { historyHandler.selectedCommitFilePath }
    var historyDiffDocument: DiffDocument { historyHandler.diffDocument }
    var isLoadingHistoryDiff: Bool { historyHandler.isLoadingDiff }
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
        (commitForm.isAmendMode || !changedFilesHandler.checkedPaths.isEmpty) &&
        !commitForm.trimmedSummary.isEmpty &&
        !hasCheckedConflicts
    }

    var hasCheckedConflicts: Bool {
        changedFiles
            .filter { changedFilesHandler.isChecked($0.path) }
            .contains { $0.hasConflict }
    }

    var isSyncing: Bool {
        switch primaryAction {
        case .fetch, .pull, .push, .forcePush, .sync:
            return true
        default:
            return false
        }
    }

    // MARK: - Init

    init(
        inspector: RepositoryInspecting,
        screenRepository: RepositoryScreenDataProviding,
        diffProvider: DiffProviding,
        commitInspector: CommitInspecting,
        commitProvider: CommitProviding,
        repositoryPersistence: RepositoryPersistenceProviding,
        discardProvider: DiscardProviding? = nil,
        stashProvider: StashProviding? = nil,
        branchProvider: BranchProviding? = nil,
        branchOperator: BranchOperating? = nil,
        statusProvider: StatusProviding? = nil
    ) {
        self.inspector = inspector
        self.screenRepository = screenRepository
        self.diffProvider = diffProvider
        self.commitInspector = commitInspector
        self.commitProvider = commitProvider
        self.repositoryPersistence = repositoryPersistence
        self.discardProvider = discardProvider
        self.stashProvider = stashProvider
        self.branchProvider = branchProvider
        self.branchOperator = branchOperator
        self.statusProvider = statusProvider
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

    // MARK: - Delegated to handlers

    func selectHistoryCommit(at index: Int) {
        historyHandler.selectCommit(at: index)
        guard let repository = selectedRepository,
              let sha = selectedCommit?.id else { return }
        let inspector = commitInspector
        let provider = diffProvider
        let url = repository.url
        Task { [weak self] in
            guard let self else { return }
            await self.historyHandler.loadFiles(for: sha, using: inspector, in: url)
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
        guard canCommitChanges, !hasCheckedConflicts, let repository = selectedRepository else { return }

        let summary = commitForm.trimmedSummary
        let description = commitForm.trimmedDescription
        let pathsToCommit = changedFilesHandler.checkedPaths.sorted()

        commitForm.setCommitting(true)
        errorMessage = nil
        defer { commitForm.setCommitting(false) }

        let options = CommitOptions(
            skipHooks: commitForm.skipHooks,
            signOff: commitForm.signOff,
            isAmend: commitForm.isAmendMode
        )

        do {
            try await commitProvider.commit(
                in: repository.url,
                paths: pathsToCommit,
                summary: summary,
                description: description.isEmpty ? nil : description,
                options: options
            )
            commitForm.reset()
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoCommit() async {
        guard let repository = selectedRepository else { return }
        errorMessage = nil
        do {
            try await commitProvider.undoLastCommit(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Discard

    func discardChanges(path: String) async {
        guard let repository = selectedRepository,
              let discardProvider,
              let file = changedFiles.first(where: { $0.path == path }) else { return }
        errorMessage = nil
        do {
            try await discardProvider.discardChanges(in: repository.url, for: path, status: file.status)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reveal in Finder

    func revealInFinder(path: String) {
        guard let repository = selectedRepository else { return }
        let fileURL = repository.url.appendingPathComponent(path)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    // MARK: - File context actions

    var selectedEditorName: String? {
        guard let bundleID = UserDefaults.standard.string(forKey: ExternalEditorPreferences.selectedEditorKey),
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: appURL) else { return nil }
        return (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
    }

    func openInExternalEditor(path: String) {
        guard let repository = selectedRepository else { return }
        let fileURL = repository.url.appendingPathComponent(path)
        guard let bundleID = UserDefaults.standard.string(forKey: ExternalEditorPreferences.selectedEditorKey),
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSWorkspace.shared.open(fileURL)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
    }

    func openWithDefaultProgram(path: String) {
        guard let repository = selectedRepository else { return }
        NSWorkspace.shared.open(repository.url.appendingPathComponent(path))
    }

    func copyFilePath(path: String) {
        guard let repository = selectedRepository else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(repository.url.appendingPathComponent(path).path, forType: .string)
    }

    func copyRelativeFilePath(path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    // MARK: - Select / Deselect all

    func selectAllChangedFiles() {
        changedFilesHandler.selectAll(paths: changedFiles.map(\.path))
    }

    func deselectAllChangedFiles() {
        changedFilesHandler.deselectAll()
    }

    // MARK: - Commit warning

    var commitWarning: CommitWarningKind? {
        switch tip {
        case .detached: return .detachedHead
        case .unborn: return .unborn
        default: return nil
        }
    }

    // MARK: - Stash

    private(set) var stashEntry: StashEntry?

    func applyStash() async {
        guard let repository = selectedRepository, let stashProvider else { return }
        errorMessage = nil
        do {
            try await stashProvider.applyStash(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dropStash() async {
        guard let repository = selectedRepository, let stashProvider else { return }
        errorMessage = nil
        do {
            try await stashProvider.dropStash(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Amend

    // MARK: - Branches

    /// Factory for the branches panel VM. Returns `nil` when the host did not
    /// inject the branch services (e.g. preview / test scaffolding) — callers
    /// should hide the affordance in that case.
    func makeBranchesViewModel() -> BranchesViewModel? {
        guard let branchProvider, let branchOperator, let statusProvider else { return nil }
        let viewModel = BranchesViewModel(
            branchProvider: branchProvider,
            branchOperator: branchOperator,
            statusProvider: statusProvider
        )
        viewModel.setRepository(selectedRepository?.url, currentBranchName: currentBranchName)
        return viewModel
    }

    /// Short name of the checked-out branch, derived from `tip`. `nil` for
    /// detached / unborn / unknown states.
    private var currentBranchName: String? {
        if case .valid(let summary) = tip { return summary.name }
        return nil
    }

    func toggleAmendMode() {
        commitForm.toggleAmend()
        if commitForm.isAmendMode, let last = commits.first {
            commitForm.reset()
            commitForm.prefill(summary: last.summary, body: last.body)
        }
    }
}
