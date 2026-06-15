import XCTest
@testable import GimMac

/// Integration tests for merge-conflict detection and resolution against real
/// temporary repositories. Exercises `GitConflictService` plus the
/// continue/abort half of `GitMergeService` / `GitRebaseService`.
final class GitConflictIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - Detection

    func testDetectsBothModifiedConflict() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = GitConflictService(client: client)
        let files = try await sut.conflictedFiles(in: root)

        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(file.path, "conflict.txt")
        XCTAssertEqual(file.summary, .bothModified)
        // Both sides changed the same line, so there is at least one marker.
        XCTAssertGreaterThanOrEqual(file.conflictMarkerCount ?? 0, 1)
    }

    // MARK: - Resolution

    func testResolveUsingOursStagesOurContent() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = GitConflictService(client: client)
        try await sut.stageManualConflictResolution(
            "conflict.txt", summary: .bothModified, resolution: .ours, in: root
        )

        // No remaining conflicts; file holds our content; nothing is left unmerged.
        let remaining = try await sut.conflictedFiles(in: root)
        XCTAssertTrue(remaining.isEmpty)
        let contents = try String(contentsOf: root.appendingPathComponent("conflict.txt"), encoding: .utf8)
        XCTAssertEqual(contents.trimmingCharacters(in: .whitespacesAndNewlines), "ours")
    }

    func testResolveUsingTheirsStagesTheirContent() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = GitConflictService(client: client)
        try await sut.stageManualConflictResolution(
            "conflict.txt", summary: .bothModified, resolution: .theirs, in: root
        )

        let contents = try String(contentsOf: root.appendingPathComponent("conflict.txt"), encoding: .utf8)
        XCTAssertEqual(contents.trimmingCharacters(in: .whitespacesAndNewlines), "theirs")
    }

    // MARK: - Continue / Abort

    func testCreateMergeCommitFinalizesResolvedMerge() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }

        let conflicts = GitConflictService(client: client)
        try await conflicts.stageManualConflictResolution(
            "conflict.txt", summary: .bothModified, resolution: .ours, in: root
        )

        let merge = GitMergeService(client: client)
        try await merge.createMergeCommit(in: root)

        // Clean tree, no MERGE_HEAD, and the new commit has two parents.
        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(".git/MERGE_HEAD").path
        ))
        let parents = try runGitCapturing(["rev-list", "--parents", "-n", "1", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        XCTAssertEqual(parents.count, 3, "merge commit should have two parents")
    }

    func testAbortMergeRestoresCleanTree() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }
        let headBeforeAbort = try headCommitSHA(in: root)

        let merge = GitMergeService(client: client)
        try await merge.abortMerge(in: root)

        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
        XCTAssertEqual(try headCommitSHA(in: root), headBeforeAbort)
        let contents = try String(contentsOf: root.appendingPathComponent("conflict.txt"), encoding: .utf8)
        XCTAssertEqual(contents.trimmingCharacters(in: .whitespacesAndNewlines), "ours")
    }

    func testResolveAndContinueRebase() async throws {
        let root = try makeConflictingRebase()
        defer { try? FileManager.default.removeItem(at: root) }

        let conflicts = GitConflictService(client: client)
        let files = try await conflicts.conflictedFiles(in: root)
        XCTAssertEqual(files.first?.path, "conflict.txt")

        try await conflicts.stageManualConflictResolution(
            "conflict.txt", summary: .bothModified, resolution: .theirs, in: root
        )

        let rebase = GitRebaseService(client: client)
        let outcome = try await rebase.continueRebase(in: root)
        XCTAssertEqual(outcome, .completed)

        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    // MARK: - Conflict fixtures

    /// Builds a repo paused mid-merge with a single both-modified conflict in
    /// `conflict.txt`. The current branch ("ours") holds "ours"; the merged
    /// branch ("theirs") holds "theirs".
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

        // Merge "theirs" into main — conflicts, leaving the repo mid-merge.
        _ = try? runGitCapturingAllowingFailure(["merge", "theirs"], in: root)
        return root
    }

    /// Builds a repo paused mid-rebase with a both-modified conflict.
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

        // Rebase feature onto main — conflicts, leaving the repo mid-rebase.
        _ = try? runGitCapturingAllowingFailure(["rebase", "main", "feature"], in: root)
        return root
    }

    // MARK: - Helpers

    private func headCommitSHA(in root: URL) throws -> String {
        try runGitCapturing(["rev-parse", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(_ name: String, _ contents: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
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
        let result = try runGitRaw(args, in: directory)
        if result.status != 0 { XCTFail("git \(args.joined(separator: " ")) failed: \(result.stderr)") }
        return result.output
    }

    /// Runs git without failing the test on a non-zero exit — used for the
    /// merge/rebase steps that are *expected* to stop on conflicts.
    @discardableResult
    private func runGitCapturingAllowingFailure(_ args: [String], in directory: URL) throws -> String {
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
