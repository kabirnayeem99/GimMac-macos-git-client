import XCTest
@testable import GimMac

/// Integration tests for the menu-bar Phase 3 git services against real
/// temporary repositories: init, clone, merge, squash-merge, rebase, and
/// discard-all.
final class GitPhase3IntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    // MARK: - init

    func testInitCreatesGitRepository() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = GitRepositoryInitService(client: client)
        try await sut.initRepository(at: root)

        let gitDir = root.appendingPathComponent(".git")
        XCTAssertTrue(FileManager.default.fileExists(atPath: gitDir.path))

        // The repository must be usable: rev-parse should succeed.
        let result = try await client.run(["rev-parse", "--is-inside-work-tree"], in: root, timeout: 10)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "true")
    }

    // MARK: - clone

    func testCloneCopiesCommitsFromSourceRepository() async throws {
        let source = try makeCommittedRepository(fileName: "README.md", contents: "hello")
        defer { try? FileManager.default.removeItem(at: source) }

        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let destination = parent.appendingPathComponent("clone", isDirectory: true)

        let sut = GitRepositoryCloneService(client: client)
        try await sut.clone(from: source.path, to: destination)

        let clonedFile = destination.appendingPathComponent("README.md")
        XCTAssertEqual(try String(contentsOf: clonedFile, encoding: .utf8), "hello")
    }

    // MARK: - merge

    func testMergeFastForwardSucceeds() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let base = defaultBranchName(in: root)

        try runGit(["checkout", "-b", "feature"], in: root)
        try writeAndCommit("a.txt", "feature change", in: root)
        try runGit(["checkout", base], in: root)

        let sut = GitMergeService(client: client)
        let outcome = try await sut.merge(branch: "feature", noVerify: false, in: root)
        XCTAssertEqual(outcome, .success)
    }

    func testMergeAlreadyUpToDate() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }

        // Create a branch but add no new commits; merging it is a noop.
        try runGit(["branch", "stale"], in: root)

        let sut = GitMergeService(client: client)
        let outcome = try await sut.merge(branch: "stale", noVerify: false, in: root)
        XCTAssertEqual(outcome, .alreadyUpToDate)
    }

    func testMergeWithConflictsReportsConflicts() async throws {
        let root = try makeConflictingBranches(file: "a.txt")
        defer { try? FileManager.default.removeItem(at: root) }

        let sut = GitMergeService(client: client)
        let outcome = try await sut.merge(branch: "feature", noVerify: false, in: root)
        XCTAssertEqual(outcome, .conflicts)

        // Abort restores a clean tree.
        try await sut.abortMerge(in: root)
        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    func testSquashMergeProducesSingleCommit() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let base = defaultBranchName(in: root)

        try runGit(["checkout", "-b", "feature"], in: root)
        try writeAndCommit("b.txt", "one", in: root)
        try writeAndCommit("c.txt", "two", in: root)
        try runGit(["checkout", base], in: root)

        let countBefore = try commitCount(in: root)
        let sut = GitMergeService(client: client)
        let outcome = try await sut.squashMerge(branch: "feature", noVerify: false, in: root)
        XCTAssertEqual(outcome, .success)

        // Two feature commits collapse into exactly one new commit on the base.
        XCTAssertEqual(try commitCount(in: root), countBefore + 1)
    }

    // MARK: - rebase

    func testRebaseCompletes() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base")
        defer { try? FileManager.default.removeItem(at: root) }
        let base = defaultBranchName(in: root)

        try runGit(["checkout", "-b", "feature"], in: root)
        try writeAndCommit("feature.txt", "feature", in: root)
        try runGit(["checkout", base], in: root)
        try writeAndCommit("main.txt", "main", in: root)

        let sut = GitRebaseService(client: client)
        let outcome = try await sut.rebase(base: base, target: "feature", in: root)
        XCTAssertEqual(outcome, .completed)
    }

    func testRebaseWithConflictsReportsConflictsAndAborts() async throws {
        let root = try makeConflictingBranches(file: "a.txt")
        defer { try? FileManager.default.removeItem(at: root) }
        let base = defaultBranchName(in: root)

        let sut = GitRebaseService(client: client)
        let outcome = try await sut.rebase(base: base, target: "feature", in: root)
        XCTAssertEqual(outcome, .conflicts)

        try await sut.abortRebase(in: root)
        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    // MARK: - discard all

    func testDiscardAllChangesRevertsTrackedAndRemovesUntracked() async throws {
        let root = try makeCommittedRepository(fileName: "tracked.txt", contents: "original")
        defer { try? FileManager.default.removeItem(at: root) }

        // Modify a tracked file and add an untracked one.
        try "modified".write(to: root.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
        try "junk".write(to: root.appendingPathComponent("untracked.txt"), atomically: true, encoding: .utf8)

        let sut = GitDiscardProvider(client: client)
        try await sut.discardAllChanges(in: root)

        let tracked = try String(contentsOf: root.appendingPathComponent("tracked.txt"), encoding: .utf8)
        XCTAssertEqual(tracked, "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("untracked.txt").path))

        let status = try await client.run(["status", "--porcelain"], in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Init a repo and create an initial commit containing `fileName`.
    private func makeCommittedRepository(fileName: String, contents: String) throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init"], in: root)
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        try runGit(["add", "--", fileName], in: root)
        try commit("initial", in: root)
        return root
    }

    /// Repo with `main` and `feature` branches that both edit the same line of
    /// `file`, guaranteeing a conflict on merge/rebase.
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
