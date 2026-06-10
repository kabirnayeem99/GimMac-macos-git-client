import XCTest
@testable import GimMac

/// Integration tests for the History-screen edit services (revert, cherry-pick)
/// against real temporary repositories, including the conflict-abort paths.
final class GitHistoryEditIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - revert

    func testRevertUndoesCommitAndAddsRevertCommit() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeAndCommit("a.txt", "changed\n", in: root)
        let headSHA = try headCommitSHA(in: root)
        let countBefore = try commitCount(in: root)

        let sut = GitRevertProvider(client: client)
        try await sut.revert(commit: commitObject(sha: headSHA), in: root)

        // The file content is restored and a new revert commit sits on top.
        let restored = try String(contentsOf: root.appendingPathComponent("a.txt"), encoding: .utf8)
        XCTAssertEqual(restored, "base\n")
        XCTAssertEqual(try commitCount(in: root), countBefore + 1)

        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    // MARK: - cherry-pick

    func testCherryPickAppliesCommitOntoCurrentBranch() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let base = defaultBranchName(in: root)

        try runGit(["checkout", "-b", "feature"], in: root)
        try writeAndCommit("b.txt", "one", in: root)
        let pickSHA = try headCommitSHA(in: root)
        try runGit(["checkout", base], in: root)

        let countBefore = try commitCount(in: root)
        let sut = GitCherryPickProvider(client: client)
        try await sut.cherryPick(commits: [commitObject(sha: pickSHA)], in: root)

        // The feature-only file is now present on the base branch.
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("b.txt").path))
        XCTAssertEqual(try commitCount(in: root), countBefore + 1)
    }

    func testCherryPickWithConflictThrowsAndAborts() async throws {
        let root = try makeConflictingBranches(file: "a.txt")
        defer { try? FileManager.default.removeItem(at: root) }

        // Currently on the base branch; cherry-picking feature's tip conflicts.
        let featureSHA = try runGitCapturing(["rev-parse", "feature"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sut = GitCherryPickProvider(client: client)
        do {
            try await sut.cherryPick(commits: [commitObject(sha: featureSHA)], in: root)
            XCTFail("Expected cherry-pick to throw on conflict")
        } catch {
            XCTAssertTrue(error is GitAppError)
        }

        // The abort left a clean working tree, not a half-applied cherry-pick.
        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    // MARK: - Helpers

    /// Minimal `Commit` carrying only the SHA the providers consume.
    private func commitObject(sha: String) -> Commit {
        Commit(
            id: sha,
            shortHash: String(sha.prefix(7)),
            authorName: "Test",
            authorEmail: "test@example.com",
            date: Date(timeIntervalSince1970: 0),
            summary: "test",
            body: nil
        )
    }

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

    private func makeCommittedRepository(fileName: String, contents: String) throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init"], in: root)
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        try runGit(["add", "--", fileName], in: root)
        try commit("initial", in: root)
        return root
    }

    private func makeConflictingBranches(file: String) throws -> URL {
        let root = try makeCommittedRepository(fileName: file, contents: "base\n")
        let base = defaultBranchName(in: root)

        try runGit(["checkout", "-b", "feature"], in: root)
        try writeAndCommit(file, "feature\n", in: root)

        try runGit(["checkout", base], in: root)
        try writeAndCommit(file, "main\n", in: root)
        return root
    }

    private func writeAndCommit(_ fileName: String, _ contents: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        try runGit(["add", "--", fileName], in: root)
        try commit("change \(fileName)", in: root)
    }

    private func commit(_ message: String, in root: URL) throws {
        try runGit([
            "-c", "user.name=Test",
            "-c", "user.email=test@example.com",
            "-c", "commit.gpgsign=false",
            "commit", "-m", message
        ], in: root)
    }

    private func commitCount(in root: URL) throws -> Int {
        let output = try runGitCapturing(["rev-list", "--count", "HEAD"], in: root)
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
    }

    private func defaultBranchName(in root: URL) -> String {
        (try? runGitCapturing(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? "main"
    }

    private func runGit(_ args: [String], in directory: URL) throws {
        _ = try runGitCapturing(args, in: directory)
    }

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
