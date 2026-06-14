import XCTest
@testable import GimMac

/// Integration tests for branch inspection, listing, and deletion against real
/// temporary repositories. Mirrors the *conditions* of GitHub Desktop's
/// `app/test/unit/git/branch-test.ts` (tip / getBranchesPointedAt /
/// deleteLocalBranch / deleteRemoteBranch), adapted to GimMac's API.
///
/// Behavior notes vs the GitHub Desktop reference:
///
/// 1. **Detached tip carries the full SHA**, matching the reference's
///    `IDetachedHead.currentSha`. `LocalGitRepositoryInspector` stores the full
///    `rev-parse HEAD`; the branch UI (`RepositoryBranchDisplayFormatter`)
///    abbreviates it for display.
///
/// 2. **Malformed committish throws instead of returning nil.** The reference
///    `getBranchesPointedAt` returns `null` for a bad committish (e.g.
///    `MERGE_HEAD` with no merge in progress). GimMac has no nullable return;
///    `git branch --points-at=MERGE_HEAD` exits 129 ("malformed object name")
///    and `ProcessGitClient` maps that to a thrown `GitAppError`. Intentional —
///    typed-error propagation over sentinel nil.
///
/// 3. **Deleting an already-removed remote branch succeeds (idempotent)**,
///    matching the reference: `GitBranchOperator.deleteRemoteBranch` swallows
///    the "remote ref does not exist" failure and prunes the local
///    remote-tracking ref, as the push would have done.
///
/// 4. **Upstream decomposition matches the reference.** `Branch.upstreamRemoteName`
///    and `Branch.upstreamWithoutRemote` split `Branch.upstream` (e.g.
///    `bassoon/master` → `bassoon` / `master`). Note `TipState.valid` still
///    carries only name/sha (upstream nil) — the decomposition lives on `Branch`,
///    surfaced via `GitBranchReader`, not on the tip summary.
final class GitBranchIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - tip

    /// Reference: "returns unborn for new repository" — empty repo → Unborn/master.
    func testTipIsUnbornForNewRepository() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = LocalGitRepositoryInspector(gitClient: client)
        let tip = try await sut.inspectRepository(at: root)

        XCTAssertEqual(tip, .unborn(ref: "master"))
    }

    /// Reference: "returns correct ref if checkout occurs" — `checkout -b` in an
    /// empty repo updates the unborn ref name.
    func testTipIsUnbornWithNewRefAfterCheckoutInEmptyRepository() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try runGit(["checkout", "-b", "not-master"], in: root)

        let sut = LocalGitRepositoryInspector(gitClient: client)
        let tip = try await sut.inspectRepository(at: root)

        XCTAssertEqual(tip, .unborn(ref: "not-master"))
    }

    /// Reference: "returns detached for arbitrary checkout" — tip carries the
    /// full SHA (note #1).
    func testTipIsDetachedForArbitraryCheckout() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)
        try commitEmpty("c2", in: root)
        let headSHA = try revParse("HEAD", in: root)
        // Detach HEAD by checking out the commit directly.
        try runGit(["checkout", "--detach", headSHA], in: root)

        let sut = LocalGitRepositoryInspector(gitClient: client)
        let tip = try await sut.inspectRepository(at: root)

        XCTAssertEqual(tip, .detached(sha: headSHA))
    }

    /// Reference: "returns current branch when on a valid HEAD".
    func testTipIsValidOnBranchWithCommits() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)
        let headSHA = try revParse("HEAD", in: root)

        let sut = LocalGitRepositoryInspector(gitClient: client)
        let tip = try await sut.inspectRepository(at: root)

        XCTAssertEqual(tip, .valid(branch: BranchSummary(name: "master", upstream: nil, sha: headSHA)))
    }

    // MARK: - upstream capture (reference: tip non-origin remote / upstreamWithoutRemote)

    /// Reference: tip non-origin remote + `upstreamWithoutRemote`. A local
    /// branch tracking a non-`origin` remote (`bassoon`) exposes the full
    /// upstream and its decomposition (note #4).
    func testFetchBranchesCapturesNonOriginUpstream() async throws {
        // origin repo (acts as the "bassoon" remote) with a commit on master.
        let origin = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: origin) }
        try commitEmpty("c1", in: origin)

        // Local clone with the remote named "bassoon" rather than "origin".
        let local = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: local) }
        try runGit(["clone", "--origin", "bassoon", origin.path, local.path], in: local.deletingLastPathComponent())
        // Ensure master tracks bassoon/master explicitly.
        try runGit(["branch", "--set-upstream-to=bassoon/master", "master"], in: local)

        let reader = GitBranchReader(client: client)
        let branches = try await reader.fetchBranches(in: local)

        let master = try XCTUnwrap(branches.first { $0.name == "master" && $0.isLocal })
        XCTAssertEqual(master.upstream, "bassoon/master")
        XCTAssertEqual(master.upstreamRemoteName, "bassoon")
        XCTAssertEqual(master.upstreamWithoutRemote, "master")
    }

    // MARK: - getBranchesPointedAt → fetchBranchesPointing

    /// Reference: "finds one branch name" — exactly the current branch at HEAD.
    func testFetchBranchesPointingAtHeadFindsOneBranch() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)

        let reader = GitBranchReader(client: client)
        let branches = try await reader.fetchBranchesPointing(at: "HEAD", in: root)

        XCTAssertEqual(branches.count, 1)
        XCTAssertEqual(branches.first?.name, "master")
    }

    /// Reference: "finds no branch names" at a parent commit. Requires two
    /// commits so `HEAD^` resolves to an addressable commit with no branch on it.
    func testFetchBranchesPointingAtParentFindsNoBranches() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)
        try commitEmpty("c2", in: root)

        let reader = GitBranchReader(client: client)
        let branches = try await reader.fetchBranchesPointing(at: "HEAD^", in: root)

        XCTAssertTrue(branches.isEmpty)
    }

    /// Reference: "returns null on a malformed committish". GimMac throws a
    /// typed `GitAppError` instead of returning nil (divergence #2).
    func testFetchBranchesPointingAtMalformedCommittishThrows() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)

        let reader = GitBranchReader(client: client)
        do {
            _ = try await reader.fetchBranchesPointing(at: "MERGE_HEAD", in: root)
            XCTFail("Expected malformed committish to throw")
        } catch {
            XCTAssertTrue(error is GitAppError, "Expected GitAppError, got \(error)")
        }
    }

    /// Reference: "finds multiple branch names" when several local branches
    /// point at the same commit.
    func testFetchBranchesPointingFindsMultipleBranchesAtSameCommit() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)
        try runGit(["branch", "other-branch"], in: root)

        let reader = GitBranchReader(client: client)
        let names = Set(try await reader.fetchBranchesPointing(at: "HEAD", in: root).map(\.name))

        XCTAssertEqual(names, ["master", "other-branch"])
    }

    // MARK: - deleteLocalBranch

    /// Reference: "deletes local branches" — branch no longer appears for its ref.
    func testDeleteLocalBranchRemovesItFromBranchList() async throws {
        let root = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: root) }
        try commitEmpty("c1", in: root)
        try runGit(["branch", "test-branch"], in: root)

        let reader = GitBranchReader(client: client)
        let operator_ = GitBranchOperator(client: client)

        let before = try await reader.fetchBranches(in: root)
        let target = try XCTUnwrap(before.first { $0.name == "test-branch" })

        try await operator_.deleteLocalBranch(target, force: false, in: root)

        let after = try await reader.fetchBranches(in: root)
        XCTAssertFalse(after.contains { $0.name == "test-branch" })
    }

    // MARK: - deleteRemoteBranch

    /// Reference: "delete a local branch's upstream branch" — deleting the
    /// remote branch removes it from the remote, leaving the local repo's other
    /// refs intact.
    func testDeleteRemoteBranchRemovesBranchFromRemote() async throws {
        let origin = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: origin) }
        try commitEmpty("c1", in: origin)
        try runGit(["branch", "feature"], in: origin)

        let local = try cloneRepository(origin)
        defer { try? FileManager.default.removeItem(at: local) }

        let reader = GitBranchReader(client: client)
        let localBranches = try await reader.fetchBranches(in: local)
        let remoteBranch = try XCTUnwrap(localBranches.first { $0.name == "origin/feature" })

        let operator_ = GitBranchOperator(client: client)
        try await operator_.deleteRemoteBranch(remoteBranch, remote: "origin", in: local)

        // The branch is gone on the remote.
        let originBranches = try runGitCapturing(["branch", "--list", "feature"], in: origin)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(originBranches.isEmpty)
    }

    /// Reference: "handles attempted delete of removed remote branch" — treated
    /// as idempotent success. Deleting a remote branch that is already gone must
    /// not throw (note #3).
    func testDeleteAlreadyRemovedRemoteBranchSucceeds() async throws {
        let origin = try makeEmptyRepository(initialBranch: "master")
        defer { try? FileManager.default.removeItem(at: origin) }
        try commitEmpty("c1", in: origin)
        try runGit(["branch", "feature"], in: origin)

        let local = try cloneRepository(origin)
        defer { try? FileManager.default.removeItem(at: local) }

        let reader = GitBranchReader(client: client)
        let localBranches = try await reader.fetchBranches(in: local)
        let remoteBranch = try XCTUnwrap(localBranches.first { $0.name == "origin/feature" })

        let operator_ = GitBranchOperator(client: client)
        try await operator_.deleteRemoteBranch(remoteBranch, remote: "origin", in: local)

        // Second delete: the remote ref is already gone — must succeed silently.
        try await operator_.deleteRemoteBranch(remoteBranch, remote: "origin", in: local)
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Initializes an empty repository with a deterministic initial branch so
    /// ref-name assertions don't depend on the host's `init.defaultBranch`.
    private func makeEmptyRepository(initialBranch: String) throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", initialBranch], in: root)
        return root
    }

    private func cloneRepository(_ source: URL) throws -> URL {
        let dest = try makeTemporaryDirectory()
        // Clone into `dest` itself (already created, empty).
        try runGit(["clone", source.path, dest.path], in: dest.deletingLastPathComponent())
        return dest
    }

    private func commitEmpty(_ message: String, in root: URL) throws {
        try runGit([
            "-c", "user.name=Test",
            "-c", "user.email=test@example.com",
            "-c", "commit.gpgsign=false",
            "commit", "--allow-empty", "-m", message
        ], in: root)
    }

    private func revParse(_ rev: String, in root: URL) throws -> String {
        try runGitCapturing(["rev-parse", rev], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runGit(_ args: [String], in directory: URL) throws {
        _ = try runGitCapturing(args, in: directory)
    }

    @discardableResult
    private func runGitCapturing(_ args: [String], in directory: URL) throws -> String {
        let process = Process()
        process.currentDirectoryURL = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("git \(args.joined(separator: " ")) failed: \(err)")
        }
        return String(data: outData, encoding: .utf8) ?? ""
    }
}
