import Foundation

protocol HistoryProviding: Sendable {
    func fetchHistory(in repositoryURL: URL, maxCount: Int?) async throws -> [Commit]
}

protocol StatusProviding: Sendable {
    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile]
}

protocol DiffProviding: Sendable {
    func fetchDiff(in repositoryURL: URL, for path: String) async throws -> DiffDocument
    func fetchCommitDiff(in repositoryURL: URL, for path: String, commitSHA: String) async throws -> DiffDocument
}

protocol CommitInspecting: Sendable {
    func fetchFiles(for commitSHA: String, in repositoryURL: URL) async throws -> [CommitFile]
}

struct CommitOptions: Equatable, Sendable {
    var skipHooks: Bool = false
    var signOff: Bool = false
    var isAmend: Bool = false
}

protocol CommitProviding: Sendable {
    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?,
        options: CommitOptions
    ) async throws

    func undoLastCommit(in repositoryURL: URL) async throws
}

protocol RepositoryPersistenceProviding: Sendable {
    func saveOrUpdateRepository(path: String) async throws -> StoredRepository
    func getAllRepositoriesSortedByLastOpened() async throws -> [StoredRepository]
    func getCurrentlySelectedRepository() async throws -> StoredRepository?
    func selectRepository(id: UUID) async throws -> StoredRepository?
    func selectMostRecentlyOpenedRepositoryOnLaunch() async throws -> StoredRepository?
}

protocol RepositoryScreenDataProviding: Sendable {
    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot
}

protocol BranchUpstreamProviding: Sendable {
    func fetchUpstream(for branch: String, in repositoryURL: URL) async throws -> String?
}

protocol DiscardProviding: Sendable {
    func discardChanges(in repositoryURL: URL, for path: String, status: GitFileStatus) async throws
}

protocol StashProviding: Sendable {
    func fetchStash(in repositoryURL: URL) async throws -> StashEntry?
    func applyStash(in repositoryURL: URL) async throws
    func dropStash(in repositoryURL: URL) async throws
    /// Push a new stash with the current working-tree changes (including untracked).
    /// Used by the stash-and-switch flow before swapping branches.
    func pushStash(in repositoryURL: URL, message: String?) async throws
}

// MARK: - Branches

/// Read-only branch discovery. Separate from `BranchOperating` so read-only
/// callers (e.g. toolbar/popover) don't gain mutate access.
protocol BranchProviding: Sendable {
    /// Fetch all local and remote branches via a single `for-each-ref` call.
    func fetchBranches(in repositoryURL: URL) async throws -> [Branch]

    /// Fetch branches that point at a given commitish.
    func fetchBranchesPointing(at commitish: String, in repositoryURL: URL) async throws -> [Branch]

    /// Fetch local branches fully merged into the given branch.
    func fetchMergedBranches(into branch: Branch, in repositoryURL: URL) async throws -> [Branch]
}

/// Mutating branch operations. Kept separate from `BranchProviding`.
protocol BranchOperating: Sendable {
    /// Create a new branch from `startPoint`. Does not switch to it.
    @discardableResult
    func createBranch(
        named name: String,
        from startPoint: BranchStartPoint,
        noTrack: Bool,
        in repositoryURL: URL
    ) async throws -> String

    /// Switch the working tree to the given branch (`git switch`).
    func switchBranch(to branch: Branch, in repositoryURL: URL) async throws

    /// Delete a local branch. `force = true` uses `-D` to skip the merge check.
    func deleteLocalBranch(_ branch: Branch, force: Bool, in repositoryURL: URL) async throws

    /// Delete a remote tracking branch via `git push remote :branchName`.
    func deleteRemoteBranch(_ branch: Branch, remote: String, in repositoryURL: URL) async throws

    /// Rename a local branch. `force = true` uses `-M` to allow overwriting.
    @discardableResult
    func renameBranch(
        _ branch: Branch,
        to newName: String,
        force: Bool,
        in repositoryURL: URL
    ) async throws -> String
}

/// Compare two arbitrary branches (not just vs upstream).
protocol BranchCompareProviding: Sendable {
    func compareBranches(
        base: Branch,
        compare: Branch,
        in repositoryURL: URL
    ) async throws -> BranchCompareResult
}

/// Merge or rebase the current branch from the default branch. Post-MVP scope,
/// protocol declared here so callers can be wired up incrementally.
protocol UpdateFromDefaultProviding: Sendable {
    func mergeDefaultBranch(into branch: Branch, in repositoryURL: URL) async throws
    func rebaseOntoDefaultBranch(_ branch: Branch, in repositoryURL: URL) async throws
}

// MARK: - Git Config

protocol GitConfigReading: Sendable {
    func globalUserName() async throws -> String?
    func globalUserEmail() async throws -> String?
}

protocol GitConfigWriting: Sendable {
    func setGlobalUserName(_ name: String) async throws
    func setGlobalUserEmail(_ email: String) async throws
}

// MARK: - Repository Settings

protocol RepositoryRemoteProviding: Sendable {
    func fetchRemoteURL(named remote: String, in repositoryURL: URL) async throws -> String?
    func setRemoteURL(_ url: String, named remote: String, in repositoryURL: URL) async throws
}

protocol LFSProviding: Sendable {
    func isLFSAvailable(in repositoryURL: URL) async throws -> Bool
    func initializeLFS(in repositoryURL: URL) async throws
}

/// String-based branch rename used by Repository Settings — avoids the `Branch`
/// object dependency in presentation-layer ViewModels.
protocol DefaultBranchRenaming: Sendable {
    func renameCurrentBranch(from oldName: String, to newName: String, in repositoryURL: URL) async throws
}

// MARK: - Remote Sync

protocol RemoteSyncProviding: Sendable {
    func fetch(remote: String, in repositoryURL: URL) async throws
    func pull(in repositoryURL: URL) async throws
    func push(remote: String, in repositoryURL: URL) async throws
    func pushForceSafely(remote: String, in repositoryURL: URL) async throws
    func publishBranch(named branch: String, remote: String, in repositoryURL: URL) async throws
}

// MARK: - Squash

protocol SquashProviding: Sendable {
    /// Squash `commits` into a single commit with `message`.
    /// `commits` must be in newest-first order (as returned by HistoryHandler).
    /// The oldest commit becomes the squash target; all others are folded into it.
    func squash(commits: [Commit], message: String, in repositoryURL: URL) async throws
}
