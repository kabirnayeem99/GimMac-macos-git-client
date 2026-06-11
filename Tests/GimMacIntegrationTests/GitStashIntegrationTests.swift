import XCTest
@testable import GimMac

/// Integration tests for multi-stash listing and ref-targeted apply/pop/drop
/// against real temporary repositories.
final class GitStashIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - fetchAllStashes

    func testFetchAllStashesReturnsNewestFirstWithIndices() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        try makeStash(file: "a.txt", contents: "one", message: "first", in: root)
        try makeStash(file: "a.txt", contents: "two", message: "second", in: root)
        try makeStash(file: "a.txt", contents: "three", message: "third", in: root)

        let sut = GitStashProvider(client: client)
        let stashes = try await sut.fetchAllStashes(in: root)

        XCTAssertEqual(stashes.count, 3)
        // Newest-first: stash@{0} is the most recently pushed ("third").
        XCTAssertEqual(stashes[0].id, "stash@{0}")
        XCTAssertEqual(stashes[0].index, 0)
        XCTAssertEqual(stashes[2].id, "stash@{2}")
        XCTAssertEqual(stashes[2].index, 2)
        XCTAssertTrue(stashes[0].message.contains("third"))
        XCTAssertTrue(stashes[2].message.contains("first"))
        XCTAssertNotNil(stashes[0].createdAt)
    }

    func testFetchAllStashesEmptyWhenNoStashes() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = GitStashProvider(client: client)
        let stashes = try await sut.fetchAllStashes(in: root)
        XCTAssertTrue(stashes.isEmpty)
    }

    // MARK: - drop(ref:)

    func testDropMiddleStashByRef() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        try makeStash(file: "a.txt", contents: "one", message: "first", in: root)
        try makeStash(file: "a.txt", contents: "two", message: "second", in: root)
        try makeStash(file: "a.txt", contents: "three", message: "third", in: root)

        let sut = GitStashProvider(client: client)
        // stash@{1} == "second".
        try await sut.dropStash(in: root, ref: "stash@{1}")

        let remaining = try await sut.fetchAllStashes(in: root)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains { $0.message.contains("second") })
    }

    // MARK: - apply(ref:) keeps; pop(ref:) removes

    func testApplyByRefKeepsStashAndRestoresChanges() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        try makeStash(file: "a.txt", contents: "stashed", message: "wip", in: root)

        let sut = GitStashProvider(client: client)
        try await sut.applyStash(in: root, ref: "stash@{0}")

        // Working tree restored.
        let contents = try String(contentsOf: root.appendingPathComponent("a.txt"), encoding: .utf8)
        XCTAssertTrue(contents.contains("stashed"))
        // Stash still present (apply does not drop).
        let stashes = try await sut.fetchAllStashes(in: root)
        XCTAssertEqual(stashes.count, 1)
    }

    func testPopByRefRemovesStash() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        try makeStash(file: "a.txt", contents: "stashed", message: "wip", in: root)

        let sut = GitStashProvider(client: client)
        try await sut.popStash(in: root, ref: "stash@{0}")

        let stashes = try await sut.fetchAllStashes(in: root)
        XCTAssertTrue(stashes.isEmpty)
    }

    // MARK: - Helpers

    /// Modify `file`, then `git stash push -m message` so a stash with a known
    /// subject lands on the stack. Leaves the working tree clean afterwards.
    private func makeStash(file: String, contents: String, message: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(file), atomically: true, encoding: .utf8)
        try runGit(["stash", "push", "-m", message], in: root)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeCommittedRepository(fileName: String, contents: String) throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init"], in: root)
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        try runGit(["add", "--", fileName], in: root)
        try runGit([
            "-c", "user.name=Test",
            "-c", "user.email=test@example.com",
            "-c", "commit.gpgsign=false",
            "commit", "-m", "initial"
        ], in: root)
        return root
    }

    private func runGit(_ args: [String], in directory: URL) throws {
        let process = Process()
        process.currentDirectoryURL = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("git \(args.joined(separator: " ")) failed: \(err)")
        }
    }
}
