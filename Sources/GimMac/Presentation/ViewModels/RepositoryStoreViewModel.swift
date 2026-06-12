import AppKit
import Foundation
import Observation

// Architecture note: AppKit is imported here only for `NSWorkspace` used to
// reveal a file in Finder. This is a small, native-only OS integration that
// avoids creating a separate service for a single one-line side effect.
//
// This type is intentionally split across `RepositoryStoreViewModel+*.swift`
// extension files (Commit, Sync, Ignore, Discard, History, FileActions,
// Branches, Stash, Repository, RepositoryManagement). The main declaration
// keeps the stored state, initializer, and the computed properties the views
// bind through; behaviour-bearing methods live in their topic extensions.

@MainActor
@Observable
final class RepositoryStoreViewModel {
    let logger: any AppLogging
    let inspector: RepositoryInspecting
    let screenRepository: RepositoryScreenDataProviding
    let diffProvider: DiffProviding
    let commitInspector: CommitInspecting
    let commitProvider: CommitProviding
    let repositoryPersistence: RepositoryPersistenceProviding
    let discardProvider: DiscardProviding?
    let gitIgnoreProvider: GitIgnoreProviding?
    let stashProvider: StashProviding?
    let branchProvider: BranchProviding?
    let branchOperator: BranchOperating?
    let statusProvider: StatusProviding?
    let remoteSyncProvider: RemoteSyncProviding?
    let compareProvider: BranchCompareProviding?
    let updateFromDefaultProvider: UpdateFromDefaultProviding?
    let squashProvider: SquashProviding?
    let repositoryInitProvider: RepositoryInitProviding?
    let repositoryCloneProvider: RepositoryCloneProviding?
    let revertProvider: RevertProviding?
    let cherryPickProvider: CherryPickProviding?
    let tagProvider: TagProviding?
    let resetProvider: ResetProviding?
    let reorderProvider: ReorderProviding?
    let conflictResolver: ConflictResolutionProviding?
    let mergeService: MergeBranchProviding?
    let rebaseService: RebaseProviding?
    let repositoryCreator: RepositoryCreating?
    let templateCatalog: RepositoryTemplateCatalog?

    let commitForm = CommitFormHandler()
    let changedFilesHandler = ChangedFilesHandler()
    let diffHandler: DiffHandler
    let historyHandler = HistoryHandler()
    var historyLoadTask: Task<Void, Never>?
    var historyFileDiffTask: Task<Void, Never>?

    var selectedRepository: Repository?
    var tip: TipState = .unknown
    var isLoading = false
    var errorMessage: String?

    var primaryAction: RepositoryPrimaryAction = .publishRepository
    var remoteName: String?
    var lastFetched: Date?
    var forcePushNeeded = false
    var isSyncInProgress = false
    var changedFiles: [ChangedFile] = []
    var commits: [Commit] = []
    var unpushedSHAs: Set<String> = []
    var currentGitUser = GitUserProfile(name: "Unknown User", email: "unknown@example.com")
    var savedRepositories: [StoredRepository] = []
    var isSquashing = false
    var isReverting = false
    var isCherryPicking = false
    var isTagging = false
    var isCreatingBranchFromCommit = false
    var isResetting = false
    var isReordering = false
    var stashEntry: StashEntry?

    /// History pagination: `canLoadMoreHistory` is true while the last page came
    /// back full (so more may exist); `isLoadingMoreHistory` guards re-entry.
    var canLoadMoreHistory = false
    var isLoadingMoreHistory = false

    // Merge-conflict resolution sheet state. `isResolvingConflicts` drives the
    // sheet; `conflictedFiles` is the live unresolved set; `initialConflictCount`
    // anchors the "X of N resolved" banner.
    var isResolvingConflicts = false
    var conflictedFiles: [ConflictedFileStatus] = []
    var initialConflictCount = 0
    var conflictMergeToolName: String?
    var isConflictActionInProgress = false

    /// Guards stash apply/drop against re-entry (e.g. double-tapping Restore or
    /// Discard) so two concurrent git stash operations cannot overlap.
    var isStashOperationInProgress = false

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
    var commitCoAuthors: [CommitAuthor] { commitForm.coAuthors }
    var selectedHistoryCommitIDs: Set<Commit.ID> { historyHandler.selectedSHAs }
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
        !hasUnresolvedConflicts
    }

    /// True when any file in the working tree has an unresolved conflict. Git
    /// blocks every commit while unmerged paths exist, so this gates on the full
    /// changed-file set — not just the checkbox-selected files.
    var hasUnresolvedConflicts: Bool {
        changedFiles.contains { $0.hasConflict }
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

    var commitWarning: CommitWarningKind? {
        switch tip {
        case .detached: return .detachedHead
        case .unborn: return .unborn
        default: return nil
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
        gitIgnoreProvider: GitIgnoreProviding? = nil,
        stashProvider: StashProviding? = nil,
        branchProvider: BranchProviding? = nil,
        branchOperator: BranchOperating? = nil,
        statusProvider: StatusProviding? = nil,
        remoteSyncProvider: RemoteSyncProviding? = nil,
        compareProvider: BranchCompareProviding? = nil,
        updateFromDefaultProvider: UpdateFromDefaultProviding? = nil,
        squashProvider: SquashProviding? = nil,
        repositoryInitProvider: RepositoryInitProviding? = nil,
        repositoryCloneProvider: RepositoryCloneProviding? = nil,
        revertProvider: RevertProviding? = nil,
        cherryPickProvider: CherryPickProviding? = nil,
        tagProvider: TagProviding? = nil,
        resetProvider: ResetProviding? = nil,
        reorderProvider: ReorderProviding? = nil,
        conflictResolver: ConflictResolutionProviding? = nil,
        mergeService: MergeBranchProviding? = nil,
        rebaseService: RebaseProviding? = nil,
        repositoryCreator: RepositoryCreating? = nil,
        templateCatalog: RepositoryTemplateCatalog? = nil
    ) {
        self.logger = logger
        self.inspector = inspector
        self.screenRepository = screenRepository
        self.diffProvider = diffProvider
        self.commitInspector = commitInspector
        self.commitProvider = commitProvider
        self.repositoryPersistence = repositoryPersistence
        self.discardProvider = discardProvider
        self.gitIgnoreProvider = gitIgnoreProvider
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
        self.revertProvider = revertProvider
        self.cherryPickProvider = cherryPickProvider
        self.tagProvider = tagProvider
        self.resetProvider = resetProvider
        self.reorderProvider = reorderProvider
        self.conflictResolver = conflictResolver
        self.mergeService = mergeService
        self.rebaseService = rebaseService
        self.repositoryCreator = repositoryCreator
        self.templateCatalog = templateCatalog
        self.diffHandler = DiffHandler(diffProvider: diffProvider)
    }
}
