import XCTest
@testable import GimMac

/// Integration tests for rename edge cases not covered by
/// `GitDiffIntegrationTests.swift`'s single-file rename tests: directory
/// renames and macOS-specific case-only renames. Split into its own file to
/// keep `GitDiffIntegrationTests`'s class body under SwiftLint's
/// `type_body_length` limit.
final class GitRenameEdgeCaseIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    private var sut: GitDiffProvider { GitDiffProvider(client: client) }

    /// A directory rename must still resolve to a per-file rename record with
    /// the correct `oldPath` for each file inside it — not a delete+add pair.
    func testDirectoryRenameDetectsPerFileRenames() async throws {
        let root = try makeEmptyRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("dir1", isDirectory: true),
            withIntermediateDirectories: true
        )
        try write("dir1/a.txt", "alpha\n", in: root)
        try write("dir1/b.txt", "beta\n", in: root)
        try runGit(["add", "-A"], in: root)
        try commit("add dir1", in: root)

        try runGit(["mv", "--", "dir1", "dir2"], in: root)

        let files = try await GitStatusProvider(client: client).fetchStatus(in: root)
        let renamedA = try XCTUnwrap(files.first { $0.path == "dir2/a.txt" })
        let renamedB = try XCTUnwrap(files.first { $0.path == "dir2/b.txt" })
        XCTAssertEqual(renamedA.oldPath, "dir1/a.txt")
        XCTAssertEqual(renamedB.oldPath, "dir1/b.txt")

        let diffA = try await sut.fetchDiff(in: root, for: "dir2/a.txt", oldPath: renamedA.oldPath)
        XCTAssertTrue(diffA.lines.isEmpty, "a pure rename should have no content hunks")
    }

    /// macOS-specific: APFS is case-insensitive by default, so a case-only
    /// rename (`notes.txt` -> `NOTES.txt`) is easy to get wrong (silent no-op,
    /// or git recording a delete+add instead of a rename). Exercises the exact
    /// call path `GitFullWorkflowIntegrationTests` uses for renames: `git mv`
    /// followed by `GitCommitProvider.commit(paths:)` with only the new path.
    func testCaseOnlyRenameIsTrackedAsARename() async throws {
        let root = try makeCommittedRepository(fileName: "notes.txt", contents: "hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try runGit(["mv", "--", "notes.txt", "NOTES.txt"], in: root)
        let commitProvider = GitCommitProvider(client: client, logger: GimMacLogger())
        try await commitProvider.commit(
            in: root, paths: ["NOTES.txt"], summary: "case-only rename",
            description: nil, options: CommitOptions()
        )

        // `fileExists` alone can't tell the two names apart on a
        // case-insensitive volume — assert on the actual directory entry and
        // git's rename record instead.
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertTrue(entries.contains("NOTES.txt"))
        XCTAssertFalse(entries.contains("notes.txt"))

        let contents = try String(contentsOf: root.appendingPathComponent("NOTES.txt"), encoding: .utf8)
        XCTAssertEqual(contents, "hello\n")

        let nameStatus = try runGitCapturing(["log", "-1", "--name-status", "--format="], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(nameStatus.hasPrefix("R100"), "expected a pure rename record, got: \(nameStatus)")

        let status = try runGitCapturing(["status", "--porcelain"], in: root)
        XCTAssertEqual(status, "")
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeEmptyRepository() throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", "main"], in: root)
        return root
    }

    private func makeCommittedRepository(fileName: String, contents: String) throws -> URL {
        let root = try makeEmptyRepository()
        try write(fileName, contents, in: root)
        try runGit(["add", "--", fileName], in: root)
        try commit("initial", in: root)
        return root
    }

    private func write(_ fileName: String, _ contents: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
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
