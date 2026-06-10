import XCTest
@testable import GimMac

/// Integration tests for History-screen tag creation and create-branch-from-commit
/// against real temporary repositories.
final class GitTagBranchIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - tag

    func testCreateLightweightTag() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let headSHA = try headCommitSHA(in: root)

        let sut = GitTagProvider(client: client)
        try await sut.createTag(named: "v1.0.0", message: nil, at: commitObject(sha: headSHA), in: root)

        let tags = try runGitCapturing(["tag", "--list"], in: root)
        XCTAssertTrue(tags.contains("v1.0.0"))

        // No message → lightweight tag (not an annotated tag object).
        let type = try runGitCapturing(["cat-file", "-t", "v1.0.0"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(type, "commit")
    }

    func testCreateAnnotatedTagCarriesMessage() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let headSHA = try headCommitSHA(in: root)

        let sut = GitTagProvider(client: client)
        try await sut.createTag(named: "v2.0.0", message: "release two", at: commitObject(sha: headSHA), in: root)

        // Message present → annotated tag object.
        let type = try runGitCapturing(["cat-file", "-t", "v2.0.0"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(type, "tag")

        let message = try runGitCapturing(["tag", "-l", "--format=%(contents:subject)", "v2.0.0"], in: root)
        XCTAssertTrue(message.contains("release two"))
    }

    func testCreateTagOnDuplicateNameThrows() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let headSHA = try headCommitSHA(in: root)

        let sut = GitTagProvider(client: client)
        try await sut.createTag(named: "dup", message: nil, at: commitObject(sha: headSHA), in: root)

        do {
            try await sut.createTag(named: "dup", message: nil, at: commitObject(sha: headSHA), in: root)
            XCTFail("Expected duplicate tag to throw")
        } catch {
            XCTAssertTrue(error is GitAppError)
        }
    }

    // MARK: - create branch from commit

    func testCreateBranchFromCommit() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        // Add a second commit so HEAD~1 is a distinct, addressable commit.
        try writeAndCommit("b.txt", "second", in: root)
        let firstSHA = try runGitCapturing(["rev-parse", "HEAD~1"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sut = GitBranchOperator(client: client)
        try await sut.createBranch(
            named: "from-first",
            from: .commit(sha: firstSHA),
            noTrack: false,
            in: root
        )

        // The new branch points exactly at the chosen commit, not HEAD.
        let branchSHA = try runGitCapturing(["rev-parse", "from-first"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(branchSHA, firstSHA)
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
