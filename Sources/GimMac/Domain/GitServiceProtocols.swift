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
    /// Remove a repository from the app's saved list. Does not touch the
    /// working directory on disk — mirrors GitHub Desktop's "Remove repository"
    /// menu item (`remove-repository`), which only forgets the bookmark.
    func removeRepository(id: UUID) async throws
}

protocol RepositoryScreenDataProviding: Sendable {
    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot
}

protocol BranchUpstreamProviding: Sendable {
    func fetchUpstream(for branch: String, in repositoryURL: URL) async throws -> String?
}

protocol DiscardProviding: Sendable {
    func discardChanges(in repositoryURL: URL, for path: String, status: GitFileStatus) async throws

    /// Discard every change in the working tree: revert tracked files and remove
    /// untracked ones. Native equivalent of GitHub Desktop's `discard-all-changes`.
    func discardAllChanges(in repositoryURL: URL) async throws
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

// MARK: - Repository Creation

/// `git init` a new repository. Native equivalent of GitHub Desktop's
/// `create-repository` menu event (`init.ts`).
protocol RepositoryInitProviding: Sendable {
    /// Initialize a repository in an existing directory. Resolves the default
    /// branch via `init.defaultBranch` global config (falling back to "main").
    func initRepository(at directoryURL: URL) async throws
}

/// `git clone` a remote repository. Native equivalent of GitHub Desktop's
/// `clone-repository` menu event (`clone.ts`).
protocol RepositoryCloneProviding: Sendable {
    /// `git clone --recursive --progress -- <url> <destination>`.
    func clone(from url: String, to destinationURL: URL) async throws
}

// MARK: - Merge

/// Outcome of a merge attempt. Mirrors GitHub Desktop's `MergeResult`.
enum MergeOutcome: Sendable, Equatable {
    /// The merge completed (fast-forward or new merge commit).
    case success
    /// Nothing to do — current branch already contains the merged branch.
    case alreadyUpToDate
    /// Merge stopped with conflicts the user must resolve.
    case conflicts
}

/// Generic merge of an arbitrary branch into the current branch. Native
/// equivalent of GitHub Desktop's `merge-branch` / `squash-and-merge-branch`
/// menu events (`merge.ts`). Distinct from `UpdateFromDefaultProviding`, which
/// only merges the default branch.
protocol MergeBranchProviding: Sendable {
    /// `git merge [--no-verify] <branch>`.
    func merge(branch: String, noVerify: Bool, in repositoryURL: URL) async throws -> MergeOutcome

    /// `git merge --squash <branch>` then `git commit --no-edit`.
    func squashMerge(branch: String, noVerify: Bool, in repositoryURL: URL) async throws -> MergeOutcome

    /// `git merge --abort` — back out of a conflicted merge.
    func abortMerge(in repositoryURL: URL) async throws
}

// MARK: - Rebase

/// Outcome of a rebase step. A conflicted step leaves the repository mid-rebase
/// awaiting `continueRebase`/`skipCommit`/`abortRebase`.
enum RebaseOutcome: Sendable, Equatable {
    case completed
    case conflicts
}

/// Rebase the current branch onto a base. Native equivalent of GitHub Desktop's
/// `rebase-branch` menu event (`rebase.ts`), including the
/// continue/skip/abort state machine.
protocol RebaseProviding: Sendable {
    /// `git rebase <base> <target>`.
    func rebase(base: String, target: String, in repositoryURL: URL) async throws -> RebaseOutcome
    /// `git rebase --continue` after resolving conflicts.
    func continueRebase(in repositoryURL: URL) async throws -> RebaseOutcome
    /// `git rebase --skip` to drop the conflicting commit.
    func skipCommit(in repositoryURL: URL) async throws -> RebaseOutcome
    /// `git rebase --abort` to restore the pre-rebase state.
    func abortRebase(in repositoryURL: URL) async throws
}

// MARK: - Squash

protocol SquashProviding: Sendable {
    /// Squash `commits` into a single commit with `message`.
    /// `commits` must be in newest-first order (as returned by HistoryHandler).
    /// The oldest commit becomes the squash target; all others are folded into it.
    func squash(commits: [Commit], message: String, in repositoryURL: URL) async throws
}
