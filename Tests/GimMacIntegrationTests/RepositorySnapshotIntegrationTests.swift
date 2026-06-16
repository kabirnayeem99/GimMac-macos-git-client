import XCTest
@testable import GimMac

/// Integration coverage for `LiveRepositoryScreenDataRepository.loadSnapshot`
/// against real temporary repositories. Exercises the force-push detection fix
/// (audit Issue 3) and the conflict-state detection rewrite (audit Issue 12).
final class RepositorySnapshotIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    private func makeSUT() -> LiveRepositoryScreenDataRepository {
        LiveRepositoryScreenDataRepository(
            statusProvider: GitStatusProvider(client: client),
            historyProvider: GitHistoryProvider(client: client),
            upstreamProvider: GitBranchUpstreamReader(client: client),
            gitClient: client
        )
    }

    private func snapshot(at root: URL) async throws -> RepositoryScreenSnapshot {
        try await makeSUT().loadSnapshot(for: Repository(url: root))
    }

    // MARK: - Issue 12: conflict state

    func testMergeConflictReportsMergePrimaryAction() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }

        let snap = try await snapshot(at: root)
        XCTAssertEqual(snap.primaryAction, .merge)
    }

    func testRebaseConflictReportsRebasePrimaryAction() async throws {
        let root = try makeConflictingRebase()
        defer { try? FileManager.default.removeItem(at: root) }

        let snap = try await snapshot(at: root)
        XCTAssertEqual(snap.primaryAction, .rebase)
    }

    func testCleanRepositoryHasNoConflictAction() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try runGit(["init", "-b", "main"], in: root)
        try writeFile("a.txt", "hello", in: root)
        try runGit(["add", "--", "a.txt"], in: root)
        try commit("init", in: root)

        let snap = try await snapshot(at: root)
        // No remote configured yet → publish, never a conflict action.
        XCTAssertNotEqual(snap.primaryAction, .merge)
        XCTAssertNotEqual(snap.primaryAction, .rebase)
        XCTAssertNotEqual(snap.primaryAction, .cherryPick)
    }

    // MARK: - Issue 3: force-push detection

    func testDivergedHistoryNeedsForcePush() async throws {
        let root = try makeDivergedFromUpstream()
        defer { try? FileManager.default.removeItem(at: root) }

        let snap = try await snapshot(at: root)
        XCTAssertTrue(snap.forcePushNeeded, "Amended (rewritten) history vs upstream must require force push")
        guard case .forcePush = snap.primaryAction else {
            return XCTFail("Expected .forcePush, got \(snap.primaryAction)")
        }
    }

    func testAheadOnlyDoesNotNeedForcePush() async throws {
        let root = try makeAheadOnlyOfUpstream()
        defer { try? FileManager.default.removeItem(at: root) }

        let snap = try await snapshot(at: root)
        XCTAssertFalse(snap.forcePushNeeded, "A fast-forwardable push must not be flagged as force push")
        guard case .push = snap.primaryAction else {
            return XCTFail("Expected .push, got \(snap.primaryAction)")
        }
    }

    // MARK: - Fixtures

    /// Repo paused mid-merge with a both-modified conflict in `conflict.txt`.
    private func makeConflictingMerge() throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", "main"], in: root)
        try writeFile("conflict.txt", "base", in: root)
        try runGit(["add", "--", "conflict.txt"], in: root)
        try commit("base", in: root)

        try runGit(["checkout", "-b", "theirs"], in: root)
        try writeFile("conflict.txt", "theirs", in: root)
        try runGit(["add", "--", "conflict.txt"], in: root)
        try commit("theirs change", in: root)

        try runGit(["checkout", "main"], in: root)
        try writeFile("conflict.txt", "ours", in: root)
        try runGit(["add", "--", "conflict.txt"], in: root)
        try commit("ours change", in: root)

        _ = try? runGitAllowingFailure(["merge", "theirs"], in: root)
        return root
    }

    /// Repo paused mid-rebase with a both-modified conflict.
    private func makeConflictingRebase() throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", "main"], in: root)
        try writeFile("conflict.txt", "base", in: root)
        try runGit(["add", "--", "conflict.txt"], in: root)
        try commit("base", in: root)

        try runGit(["checkout", "-b", "feature"], in: root)
        try writeFile("conflict.txt", "feature", in: root)
        try runGit(["add", "--", "conflict.txt"], in: root)
        try commit("feature change", in: root)

        try runGit(["checkout", "main"], in: root)
        try writeFile("conflict.txt", "mainline", in: root)
        try runGit(["add", "--", "conflict.txt"], in: root)
        try commit("mainline change", in: root)

        _ = try? runGitAllowingFailure(["rebase", "main", "feature"], in: root)
        return root
    }

    /// Repo whose only commit was amended after pushing — HEAD and `@{upstream}`
    /// have diverged (1 ahead, 1 behind), the canonical force-push case.
    private func makeDivergedFromUpstream() throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", "main"], in: root)
        try writeFile("a.txt", "first", in: root)
        try runGit(["add", "--", "a.txt"], in: root)
        try commit("first", in: root)

        try addRemoteAndPush(in: root)
        // Rewrite the pushed commit so upstream is no longer an ancestor of HEAD.
        try writeFile("a.txt", "first amended", in: root)
        try runGit(["add", "--", "a.txt"], in: root)
        try commitAmend("first amended", in: root)
        return root
    }

    /// Repo with one extra local commit on top of the pushed upstream — ahead
    /// only, so a normal (non-force) push applies.
    private func makeAheadOnlyOfUpstream() throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", "main"], in: root)
        try writeFile("a.txt", "first", in: root)
        try runGit(["add", "--", "a.txt"], in: root)
        try commit("first", in: root)

        try addRemoteAndPush(in: root)
        try writeFile("b.txt", "second", in: root)
        try runGit(["add", "--", "b.txt"], in: root)
        try commit("second", in: root)
        return root
    }

    /// Creates a bare remote, wires it as `origin`, and pushes `main` with
    /// upstream tracking.
    private func addRemoteAndPush(in root: URL) throws {
        let remote = try makeTemporaryDirectory().appendingPathComponent("origin.git", isDirectory: true)
        try runGit(["init", "--bare", remote.path], in: root)
        try runGit(["remote", "add", "origin", remote.path], in: root)
        try runGit(["push", "-u", "origin", "main"], in: root)
    }

    // MARK: - Git helpers

    private func makeTemporaryDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(_ name: String, _ contents: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func commit(_ message: String, in root: URL) throws {
        try runGit(identityArgs + ["commit", "-m", message], in: root)
    }

    private func commitAmend(_ message: String, in root: URL) throws {
        try runGit(identityArgs + ["commit", "--amend", "-m", message], in: root)
    }

    private let identityArgs = [
        "-c", "user.name=Test",
        "-c", "user.email=test@example.com",
        "-c", "commit.gpgsign=false"
    ]

    private func runGit(_ args: [String], in directory: URL) throws {
        let result = try runGitRaw(args, in: directory)
        if result.status != 0 {
            XCTFail("git \(args.joined(separator: " ")) failed: \(result.stderr)")
        }
    }

    @discardableResult
    private func runGitAllowingFailure(_ args: [String], in directory: URL) throws -> String {
        try runGitRaw(args, in: directory).output
    }

    private struct GitRunResult {
        let output: String
        let status: Int32
        let stderr: String
    }

    private func runGitRaw(_ args: [String], in directory: URL) throws -> GitRunResult {
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
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return GitRunResult(
            output: String(data: outData, encoding: .utf8) ?? "",
            status: process.terminationStatus,
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
