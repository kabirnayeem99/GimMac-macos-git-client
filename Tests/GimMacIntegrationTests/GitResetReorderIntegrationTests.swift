import XCTest
@testable import GimMac

/// Integration tests for History-screen reset-to-commit and reorder against
/// real temporary repositories.
final class GitResetReorderIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - reset

    func testSoftResetMovesHeadKeepsWorkingTree() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let firstSHA = try headCommitSHA(in: root)

        try writeAndCommit("b.txt", "second", in: root)

        let sut = GitResetProvider(client: client)
        try await sut.reset(to: commitObject(sha: firstSHA), mode: .soft, in: root)

        // HEAD moved back; b.txt's content is still on disk and staged.
        XCTAssertEqual(try headCommitSHA(in: root), firstSHA)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("b.txt").path))
        let staged = try runGitCapturing(["diff", "--cached", "--name-only"], in: root)
        XCTAssertTrue(staged.contains("b.txt"))
    }

    func testHardResetDiscardsLaterCommitAndChanges() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let firstSHA = try headCommitSHA(in: root)

        try writeAndCommit("b.txt", "second", in: root)

        let sut = GitResetProvider(client: client)
        try await sut.reset(to: commitObject(sha: firstSHA), mode: .hard, in: root)

        // HEAD moved back and b.txt is gone from the working tree.
        XCTAssertEqual(try headCommitSHA(in: root), firstSHA)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("b.txt").path))
        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    // MARK: - reorder

    func testReorderSwapsTwoCommits() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        // History oldest→newest: base, X, Y. Sidebar order (newest-first): Y, X.
        try writeAndCommit("x.txt", "x", in: root)
        let xSHA = try headCommitSHA(in: root)
        try writeAndCommit("y.txt", "y", in: root)
        let ySHA = try headCommitSHA(in: root)

        let xSummary = try summary(of: xSHA, in: root)
        let ySummary = try summary(of: ySHA, in: root)

        // Desired new order newest-first: X on top, then Y (swap of current Y, X).
        let sut = GitReorderProvider(client: client)
        try await sut.reorder(
            orderedCommits: [commitObject(sha: xSHA), commitObject(sha: ySHA)],
            in: root
        )

        // After reorder the two summaries are swapped relative to original.
        let newTop = try summary(of: "HEAD", in: root)
        let newSecond = try summary(of: "HEAD~1", in: root)
        XCTAssertEqual(newTop, xSummary)
        XCTAssertEqual(newSecond, ySummary)

        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    func testReorderLeavesEarlierCommitsUntouched() async throws {
        let root = try makeCommittedRepository(fileName: "base.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let baseSHA = try headCommitSHA(in: root)

        try writeAndCommit("x.txt", "x", in: root)
        let xSHA = try headCommitSHA(in: root)
        try writeAndCommit("y.txt", "y", in: root)
        let ySHA = try headCommitSHA(in: root)

        // Reorder only the top two; the initial commit must keep its identity.
        let sut = GitReorderProvider(client: client)
        try await sut.reorder(
            orderedCommits: [commitObject(sha: xSHA), commitObject(sha: ySHA)],
            in: root
        )

        XCTAssertEqual(try runGitCapturing(["rev-parse", "HEAD~2"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines), baseSHA)
    }

    // MARK: - Helpers

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

    private func summary(of rev: String, in root: URL) throws -> String {
        try runGitCapturing(["log", "--format=%s", "-n", "1", rev], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
