import AppKit
import Foundation
import Observation

// Architecture note: AppKit is imported here only for `NSWorkspace` used to
// reveal a file in Finder. This is a small, native-only OS integration that
// avoids creating a separate service for a single one-line side effect.

@MainActor
@Observable
final class RepositoryStoreViewModel {
    private let logger: any AppLogging
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
    private let remoteSyncProvider: RemoteSyncProviding?
    private let compareProvider: BranchCompareProviding?
    private let updateFromDefaultProvider: UpdateFromDefaultProviding?
    private let squashProvider: SquashProviding?
    private let repositoryInitProvider: RepositoryInitProviding?
    private let repositoryCloneProvider: RepositoryCloneProviding?

    let commitForm = CommitFormHandler()
    let changedFilesHandler = ChangedFilesHandler()
    let diffHandler: DiffHandler
    let historyHandler = HistoryHandler()
    private var historyLoadTask: Task<Void, Never>?

    private(set) var selectedRepository: Repository?
    private(set) var tip: TipState = .unknown
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private(set) var primaryAction: RepositoryPrimaryAction = .publishRepository
    private(set) var remoteName: String?
    private(set) var lastFetched: Date?
    private(set) var forcePushNeeded = false
    private(set) var isSyncInProgress = false
    private(set) var changedFiles: [ChangedFile] = []
    private(set) var commits: [Commit] = []
    private(set) var unpushedSHAs: Set<String> = []
    private(set) var currentGitUser = GitUserProfile(name: "Unknown User", email: "unknown@example.com")
    private(set) var savedRepositories: [StoredRepository] = []

    /// Which top-level screen tab is shown: 0 = Changes, 1 = History.
    /// Bridged from SwiftUI `@State` so the menu bar (View → Show Changes/History)
    /// can drive tab selection from the responder chain.
    var viewTab: Int = 0

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
    var selectedHistoryCommitIndices: [Int] { historyHandler.selectedIndices }
    var selectedHistoryCommits: [Commit] { historyHandler.selectedCommits(in: commits) }
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

    var isSyncing: Bool { isSyncInProgress }

    var showSyncBar: Bool {
        switch primaryAction {
        case .publishRepository, .publishBranch, .commit, .merge, .rebase, .cherryPick:
            return false
        default:
            return remoteSyncProvider != nil
        }
    }

    var canPerformPrimaryAction: Bool {
        guard remoteSyncProvider != nil, selectedRepository != nil else { return false }
        switch primaryAction {
        case .commit, .merge, .rebase, .cherryPick, .publishRepository, .publishBranch:
            return false
        default:
            return true
        }
    }

    var showForcePushOption: Bool {
        guard remoteSyncProvider != nil, remoteName != nil else { return false }
        switch primaryAction {
        case .push, .sync:
            return true
        default:
            return false
        }
    }

    // MARK: - Init

    init(
        logger: any AppLogging,
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
        statusProvider: StatusProviding? = nil,
        remoteSyncProvider: RemoteSyncProviding? = nil,
        compareProvider: BranchCompareProviding? = nil,
        updateFromDefaultProvider: UpdateFromDefaultProviding? = nil,
        squashProvider: SquashProviding? = nil,
        repositoryInitProvider: RepositoryInitProviding? = nil,
        repositoryCloneProvider: RepositoryCloneProviding? = nil
    ) {
        self.logger = logger
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
        self.remoteSyncProvider = remoteSyncProvider
        self.compareProvider = compareProvider
        self.updateFromDefaultProvider = updateFromDefaultProvider
        self.squashProvider = squashProvider
        self.repositoryInitProvider = repositoryInitProvider
        self.repositoryCloneProvider = repositoryCloneProvider
        self.diffHandler = DiffHandler(diffProvider: diffProvider)
    }

    // MARK: - Repository selection

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

    private func resetPerRepositoryState() {
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

    // MARK: - Delegated to handlers

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

    // MARK: - Squash

    private(set) var isSquashing = false

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
        guard canCommitChanges, !hasCheckedConflicts, let repository = selectedRepository else {
            logger.warning(
                "Commit guard failed — nothing to do",
                category: .commit,
                metadata: [
                    "canCommit": "\(canCommitChanges)",
                    "hasConflicts": "\(hasCheckedConflicts)",
                    "hasRepository": "\(selectedRepository != nil)"
                ]
            )
            return
        }

        let summary = commitForm.trimmedSummary
        let description = commitForm.trimmedDescription
        let pathsToCommit = changedFilesHandler.checkedPaths.sorted()

        logger.info(
            "Commit started",
            category: .commit,
            metadata: [
                "repository": repository.url.lastPathComponent,
                "files": "\(pathsToCommit.count)",
                "amend": "\(commitForm.isAmendMode)",
                "skipHooks": "\(commitForm.skipHooks)",
                "signOff": "\(commitForm.signOff)"
            ]
        )

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
            logger.info("Commit succeeded", category: .commit)
            commitForm.reset()
            await refreshRepositoryScreenData()
        } catch {
            logger.error(
                "Commit failed",
                category: .commit,
                metadata: ["error": error.localizedDescription]
            )
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

    // MARK: - Remote sync

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

            case .publishRepository, .commit, .merge, .rebase, .cherryPick:
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

    /// Stash all working-tree changes (Branch → Stash All Changes).
    func stashAllChanges() async {
        guard let repository = selectedRepository, let stashProvider else { return }
        errorMessage = nil
        do {
            try await stashProvider.pushStash(in: repository.url, message: nil)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Discard every change in the working tree (Branch → Discard All Changes).
    func discardAllChanges() async {
        guard let repository = selectedRepository, let discardProvider else { return }
        errorMessage = nil
        do {
            try await discardProvider.discardAllChanges(in: repository.url)
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
            statusProvider: statusProvider,
            compareProvider: compareProvider,
            updateFromDefaultProvider: updateFromDefaultProvider
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

    // MARK: - Create / Clone / Remove

    /// `git init` a new repository in `directoryURL`, then select it. Native
    /// equivalent of GitHub Desktop's `create-repository` menu event.
    func createRepository(at directoryURL: URL) async {
        guard let provider = repositoryInitProvider else {
            errorMessage = "Repository init service is unavailable."
            return
        }
        errorMessage = nil
        do {
            try await provider.initRepository(at: directoryURL)
            await selectRepository(at: directoryURL)
        } catch {
            logger.error(
                "Repository init failed",
                category: .repository,
                metadata: ["error": error.localizedDescription]
            )
            errorMessage = error.localizedDescription
        }
    }

    /// `git clone` `url` into `destinationURL`, then select it. Native
    /// equivalent of GitHub Desktop's `clone-repository` menu event.
    func cloneRepository(from url: String, to destinationURL: URL) async {
        guard let provider = repositoryCloneProvider else {
            errorMessage = "Clone service is unavailable."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await provider.clone(from: url, to: destinationURL)
            isLoading = false
            await selectRepository(at: destinationURL)
        } catch {
            isLoading = false
            logger.error(
                "Repository clone failed",
                category: .repository,
                metadata: ["error": error.localizedDescription]
            )
            errorMessage = error.localizedDescription
        }
    }

    /// Forget the currently selected repository. Does not delete files on
    /// disk — mirrors GitHub Desktop's `remove-repository` menu item.
    func removeSelectedRepository() async {
        guard let repo = selectedRepository else { return }
        let canonicalPath = URL(fileURLWithPath: repo.url.path, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        guard let stored = savedRepositories.first(where: {
            let storedPath = URL(fileURLWithPath: $0.path, isDirectory: true)
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
            return storedPath == canonicalPath
        }) else { return }

        errorMessage = nil
        do {
            try await repositoryPersistence.removeRepository(id: stored.id)
            selectedRepository = nil
            resetPerRepositoryState()
            await loadSavedRepositories()
            // Promote the next most-recently-opened repository, if any.
            if let next = savedRepositories.first(where: { $0.existsOnDisk }) {
                await selectPersistedRepository(id: next.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Open the selected repository in Terminal.app.
    ///
    /// Architecture note: AppKit's `NSWorkspace` is used here to launch the
    /// system Terminal at the repo path — a one-line OS integration that
    /// matches the existing `revealInFinder` pattern.
    func openInShell() {
        guard let repo = selectedRepository else { return }
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([repo.url], withApplicationAt: terminalURL, configuration: config)
    }

    func toggleAmendMode() {
        commitForm.toggleAmend()
        logger.info("Amend mode toggled", category: .commit, metadata: ["enabled": "\(commitForm.isAmendMode)"])
        if commitForm.isAmendMode, let last = commits.first {
            commitForm.reset()
            commitForm.prefill(summary: last.summary, body: last.body)
        }
    }
}
