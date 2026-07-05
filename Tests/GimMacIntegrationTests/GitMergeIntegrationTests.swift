import XCTest
@testable import GimMac

/// Integration tests for the branch-lifecycle + merge flow: create a branch,
/// diverge it from the branch it started on, merge it back with a real
/// non-fast-forward merge commit, then delete the branch locally and on a
/// remote. No dedicated merge test file existed before this — only the
/// conflict path was covered (`GitConflictIntegrationTests.swift`); a clean
/// successful merge was untested.
///
/// SUT: `GitBranchOperator` (create/switch/delete) and `GitMergeService`
/// (merge). Branch lookups go through `GitBranchReader.fetchBranches`, the
/// same pattern `GitBranchIntegrationTests.swift` uses, rather than
/// hand-constructing a `Branch`/`BranchTip`.
final class GitMergeIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - non-fast-forward merge

    /// Both `main` and `feature` gain a commit after the branch point, so the
    /// merge cannot fast-forward — it must produce a real 2-parent merge commit.
    func testNonFastForwardMergeProducesTwoParentCommit() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n", initialBranch: "main")
        defer { try? FileManager.default.removeItem(at: root) }

        let branchOperator = GitBranchOperator(client: client)
        let branchReader = GitBranchReader(client: client)
        let mergeService = GitMergeService(client: client)

        try await branchOperator.createBranch(named: "feature", from: .currentBranch, noTrack: false, in: root)
        let feature = try await branch(named: "feature", in: root, reader: branchReader)
        try await branchOperator.switchBranch(to: feature, in: root)
        try writeAndCommit("feature.txt", "feature work\n", message: "feature commit", in: root)

        let main = try await branch(named: "main", in: root, reader: branchReader)
        try await branchOperator.switchBranch(to: main, in: root)
        try writeAndCommit("main.txt", "main work\n", message: "main commit", in: root)

        let outcome = try await mergeService.merge(branch: "feature", noVerify: false, in: root)

        XCTAssertEqual(outcome, .success)
        let parents = try runGitCapturing(["rev-list", "--parents", "-n", "1", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        XCTAssertEqual(parents.count, 3, "expected HEAD + 2 parents for a real merge commit")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("feature.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("main.txt").path))
    }

    /// Merging a branch with no new commits since the current branch already
    /// contains it reports `.alreadyUpToDate` rather than creating an empty merge.
    func testMergeAlreadyUpToDateBranchReportsNoOp() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n", initialBranch: "main")
        defer { try? FileManager.default.removeItem(at: root) }

        let branchOperator = GitBranchOperator(client: client)
        let mergeService = GitMergeService(client: client)
        try await branchOperator.createBranch(named: "feature", from: .currentBranch, noTrack: false, in: root)

        let outcome = try await mergeService.merge(branch: "feature", noVerify: false, in: root)

        XCTAssertEqual(outcome, .alreadyUpToDate)
    }

    // MARK: - branch lifecycle: create → merge → delete local → delete remote

    /// Full lifecycle: a feature branch is created, pushed, merged back with a
    /// real merge commit, then deleted both locally and on the remote.
    func testBranchLifecycleCreateMergeDeleteLocalAndRemote() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n", initialBranch: "main")
        defer { try? FileManager.default.removeItem(at: root) }
        let originURL = root.deletingLastPathComponent().appendingPathComponent("\(UUID().uuidString).git")
        defer { try? FileManager.default.removeItem(at: originURL) }
        try runGit(["init", "--bare", originURL.path], in: root.deletingLastPathComponent())
        try runGit(["remote", "add", "origin", originURL.path], in: root)
        try runGit(["push", "origin", "main"], in: root)

        let branchOperator = GitBranchOperator(client: client)
        let branchReader = GitBranchReader(client: client)
        let mergeService = GitMergeService(client: client)

        try await branchOperator.createBranch(named: "feature", from: .currentBranch, noTrack: false, in: root)
        try runGit(["push", "origin", "feature"], in: root)
        let feature = try await branch(named: "feature", in: root, reader: branchReader)
        try await branchOperator.switchBranch(to: feature, in: root)
        try writeAndCommit("feature.txt", "feature work\n", message: "feature commit", in: root)

        let main = try await branch(named: "main", in: root, reader: branchReader)
        try await branchOperator.switchBranch(to: main, in: root)
        try writeAndCommit("main.txt", "main work\n", message: "main commit", in: root)

        let outcome = try await mergeService.merge(branch: "feature", noVerify: false, in: root)
        XCTAssertEqual(outcome, .success)

        // Delete local branch now that its work is merged into main.
        let mergedFeature = try await branch(named: "feature", in: root, reader: branchReader)
        try await branchOperator.deleteLocalBranch(mergedFeature, force: false, in: root)
        let localList = try runGitCapturing(["branch", "--list", "feature"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(localList.isEmpty)

        // Delete the now-merged branch on the remote too.
        let remoteFeature = try await branch(named: "origin/feature", in: root, reader: branchReader)
        try await branchOperator.deleteRemoteBranch(remoteFeature, remote: "origin", in: root)
        let remoteList = try runGitCapturing(["branch", "--list", "feature"], in: originURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(remoteList.isEmpty)

        // Deleting it again must stay idempotent (already covered for the
        // no-merge case in GitBranchIntegrationTests; confirming it still holds
        // once the branch was actually merged and its ref history matters).
        try await branchOperator.deleteRemoteBranch(remoteFeature, remote: "origin", in: root)
    }

    // MARK: - Helpers

    private func branch(named name: String, in root: URL, reader: GitBranchReader) async throws -> Branch {
        let branches = try await reader.fetchBranches(in: root)
        return try XCTUnwrap(branches.first { $0.name == name })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeCommittedRepository(fileName: String, contents: String, initialBranch: String) throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", initialBranch], in: root)
        try write(fileName, contents, in: root)
        try runGit(["add", "--", fileName], in: root)
        try commit("initial", in: root)
        return root
    }

    private func write(_ fileName: String, _ contents: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    private func writeAndCommit(_ fileName: String, _ contents: String, message: String, in root: URL) throws {
        try write(fileName, contents, in: root)
        try runGit(["add", "--", fileName], in: root)
        try commit(message, in: root)
    }

    private func commit(_ message: String, in root: URL) throws {
        try runGit([
            "-c", "user.name=Test",
            "-c", "user.email=test@example.com",
            "-c", "commit.gpgsign=false",
            "commit", "-m", message
        ], in: root)
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
