import XCTest
@testable import GimMac

/// Integration tests for working-directory status reporting against real
/// temporary repositories. GimMac equivalent of GitHub Desktop's
/// `app/test/unit/git/status-test.ts` (`getStatus`). The system under test is
/// `GitStatusProvider.fetchStatus`, which runs `git status --porcelain=v1 -uall`
/// and feeds the output through `GitStatusParser`.
///
/// Behavioral notes vs. the GitHub Desktop reference:
/// - GimMac's parser classifies a file from the index column (X) when the change
///   is staged, falling back to the worktree column (Y) otherwise. So a
///   worktree-only change (`XY = " M"`, `" D"`) is labeled `.modified` /
///   `.deleted` just like Desktop's merged `AppFileStatusKind`.
/// - Copy detection (`C`) is supported and maps to `.copied` with the source as
///   `oldPath`, mirroring Desktop's `Copied` kind.
/// - Submodule sub-status (modified/untracked/commit-changed flags) is parsed
///   from the porcelain-v2 `<sub>` field into `ChangedFile.submoduleStatus`,
///   mirroring Desktop's `SubmoduleStatus`.
/// - A directory without a `.git` makes `git status` exit non-zero, so
///   `fetchStatus` *throws* a typed `GitAppError` rather than returning a
///   null/empty status like Desktop's `getStatus`. This is intentional in
///   GimMac's error model.
final class GitStatusIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    private func makeProvider() -> GitStatusProvider {
        GitStatusProvider(client: client)
    }

    // MARK: - Unconflicted repo

    /// Mirrors "parses changed files": a tracked file is changed and reported.
    /// Staged so the index column drives the `.modified` classification.
    func testStagedModifiedFileReportedAsModified() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile("README.md", "Hi world\n", in: root)
        try runGit(["add", "--", "README.md"], in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(file.path, "README.md")
        XCTAssertEqual(file.status, .modified)
        XCTAssertTrue(file.isStaged)
        XCTAssertFalse(file.hasConflict)
    }

    /// Mirrors "parses changed files" for the worktree-only path: a tracked file
    /// modified but not staged (`XY = " M"`) is labeled `.modified` with
    /// `isStaged == false`, matching Desktop's `Modified` kind.
    func testUnstagedModifiedFileReportedAsModified() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile("README.md", "Hi world\n", in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(file.path, "README.md")
        XCTAssertEqual(file.status, .modified)
        XCTAssertFalse(file.isStaged)
        XCTAssertFalse(file.hasConflict)
    }

    /// A worktree-only deletion (`XY = " D"`) is labeled `.deleted`.
    func testUnstagedDeletionReportedAsDeleted() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.removeItem(at: root.appendingPathComponent("README.md"))

        let files = try await makeProvider().fetchStatus(in: root)

        let file = try XCTUnwrap(files.first { $0.path == "README.md" })
        XCTAssertEqual(file.status, .deleted)
        XCTAssertFalse(file.isStaged)
    }

    /// Mirrors "reflects copies": with `status.renames=copies`, a copied file is
    /// labeled `.copied` and carries the source path as `oldPath`.
    func testCopyReportedWithOldPath() async throws {
        let root = try makeInitialCommitRepo(fileName: "original.txt", contents: "shared contents\n")
        defer { try? FileManager.default.removeItem(at: root) }

        // Copy detection is opt-in; enable it like Desktop's copy test does.
        // Default `-C` matches a new file against the *pre-image* blob of a
        // modified source: so the source is changed and the copy holds the
        // source's original committed contents.
        try runGit(["config", "status.renames", "copies"], in: root)
        try writeFile("original.txt", "changed now\n", in: root)
        try writeFile("copy.txt", "shared contents\n", in: root)
        try runGit(["add", "--", "original.txt", "copy.txt"], in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        let file = try XCTUnwrap(files.first { $0.path == "copy.txt" })
        XCTAssertEqual(file.status, .copied)
        XCTAssertEqual(file.oldPath, "original.txt")
        XCTAssertTrue(file.isStaged)
    }

    /// Mirrors "returns an empty array when there are no changes".
    func testCleanRepoReturnsNoFiles() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        let files = try await makeProvider().fetchStatus(in: root)
        XCTAssertTrue(files.isEmpty)
    }

    /// Mirrors "reflects renames": old path is carried, new path is the file
    /// path. `git mv` stages the rename so the index column reports `R`.
    func testRenameReportedWithOldPath() async throws {
        let root = try makeInitialCommitRepo(fileName: "foo", contents: "foo\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try runGit(["mv", "foo", "bar"], in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(file.path, "bar")
        XCTAssertEqual(file.status, .renamed)
        XCTAssertEqual(file.oldPath, "foo")
        XCTAssertTrue(file.isStaged)
        XCTAssertFalse(file.hasConflict)
    }

    /// An untracked file is reported (`-uall` lists it individually).
    func testUntrackedFileReportedAsUntracked() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile("new.txt", "fresh\n", in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(file.path, "new.txt")
        XCTAssertEqual(file.status, .untracked)
        XCTAssertFalse(file.isStaged)
    }

    /// A staged new file reports `.added`.
    func testStagedNewFileReportedAsAdded() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile("new.txt", "fresh\n", in: root)
        try runGit(["add", "--", "new.txt"], in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        let file = try XCTUnwrap(files.first { $0.path == "new.txt" })
        XCTAssertEqual(file.status, .added)
        XCTAssertTrue(file.isStaged)
    }

    /// A staged deletion reports `.deleted`.
    func testStagedDeletionReportedAsDeleted() async throws {
        let root = try makeInitialCommitRepo(fileName: "README.md", contents: "Hello\n")
        defer { try? FileManager.default.removeItem(at: root) }

        try runGit(["rm", "--", "README.md"], in: root)

        let files = try await makeProvider().fetchStatus(in: root)

        let file = try XCTUnwrap(files.first { $0.path == "README.md" })
        XCTAssertEqual(file.status, .deleted)
        XCTAssertTrue(file.isStaged)
    }

    /// Mirrors "returns null for directory without a .git directory". GimMac
    /// diverges: `git status` exits non-zero, so `fetchStatus` throws.
    func testDirectoryWithoutGitThrows() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            _ = try await makeProvider().fetchStatus(in: root)
            XCTFail("fetchStatus should throw for a directory without a .git")
        } catch {
            // Expected: git reports "not a git repository" via a non-zero exit.
        }
    }

    // MARK: - Conflicted repo

    /// Mirrors "with conflicted repo": a both-modified merge conflict is
    /// reported with the conflict flag set. (Marker counts and the
    /// `UnmergedEntrySummary` classification live in `GitConflictService`, which
    /// has its own coverage in `GitConflictIntegrationTests`.)
    func testConflictedFileReportedWithConflictFlag() async throws {
        let root = try makeConflictingMerge()
        defer { try? FileManager.default.removeItem(at: root) }

        let files = try await makeProvider().fetchStatus(in: root)

        let file = try XCTUnwrap(files.first { $0.path == "conflict.txt" })
        XCTAssertTrue(file.hasConflict)
        XCTAssertEqual(file.status, .unmerged)
    }

    // MARK: - Submodules

    /// Mirrors "with submodules": a modified file inside the submodule sets the
    /// `modifiedChanges` flag; the entry itself is `.modified`.
    func testSubmoduleModifiedContentReportsModifiedFlag() async throws {
        let (container, superRepo) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: container) }

        try writeFile("sub/README.md", "changed\n", in: superRepo)

        let file = try await fetchSubmoduleEntry(in: superRepo)
        XCTAssertEqual(file.status, .modified)
        let sub = try XCTUnwrap(file.submoduleStatus)
        XCTAssertTrue(sub.modifiedChanges)
        XCTAssertFalse(sub.untrackedChanges)
        XCTAssertFalse(sub.commitChanged)
    }

    /// An untracked file inside the submodule sets the `untrackedChanges` flag.
    func testSubmoduleUntrackedFileReportsUntrackedFlag() async throws {
        let (container, superRepo) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: container) }

        try writeFile("sub/README.md", "changed\n", in: superRepo)
        try writeFile("sub/untracked.txt", "x\n", in: superRepo)

        let file = try await fetchSubmoduleEntry(in: superRepo)
        let sub = try XCTUnwrap(file.submoduleStatus)
        XCTAssertTrue(sub.modifiedChanges)
        XCTAssertTrue(sub.untrackedChanges)
        XCTAssertFalse(sub.commitChanged)
    }

    /// A commit made inside the submodule sets the `commitChanged` flag.
    func testSubmoduleNewCommitReportsCommitChangedFlag() async throws {
        let (container, superRepo) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: container) }

        let subWorking = superRepo.appendingPathComponent("sub")
        try writeFile("sub/README.md", "changed\n", in: superRepo)
        try runGit(["add", "--", "README.md"], in: subWorking)
        try commit("change inside submodule", in: subWorking)

        let file = try await fetchSubmoduleEntry(in: superRepo)
        let sub = try XCTUnwrap(file.submoduleStatus)
        XCTAssertTrue(sub.commitChanged)
        XCTAssertFalse(sub.modifiedChanges)
        XCTAssertFalse(sub.untrackedChanges)
    }

    // MARK: - Fixtures

    private func makeInitialCommitRepo(fileName: String, contents: String) throws -> URL {
        let root = try makeTemporaryDirectory()
        try runGit(["init", "-b", "main"], in: root)
        try writeFile(fileName, contents, in: root)
        try runGit(["add", "--", fileName], in: root)
        try commit("initial commit", in: root)
        return root
    }

    /// Builds a repo paused mid-merge with a single both-modified conflict in
    /// `conflict.txt`. Same shape as `GitConflictIntegrationTests`.
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

        _ = try? runGitCapturingAllowingFailure(["merge", "theirs"], in: root)
        return root
    }

    /// Builds a super-repo with a committed submodule at `sub/`. Returns the
    /// container (remove it to clean up both repos) and the super-repo URL. The
    /// submodule's working tree lives at `superRepo/sub`.
    private func makeSuperRepoWithSubmodule() throws -> (container: URL, superRepo: URL) {
        let container = try makeTemporaryDirectory()
        let origin = container.appendingPathComponent("origin", isDirectory: true)
        let superRepo = container.appendingPathComponent("super", isDirectory: true)
        try FileManager.default.createDirectory(at: origin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: superRepo, withIntermediateDirectories: true)

        try runGit(["init", "-b", "main"], in: origin)
        try writeFile("README.md", "hi\n", in: origin)
        try runGit(["add", "--", "README.md"], in: origin)
        try commit("submodule init", in: origin)

        try runGit(["init", "-b", "main"], in: superRepo)
        // file:// submodules require explicit opt-in on modern git.
        try runGit(
            ["-c", "protocol.file.allow=always", "submodule", "add", origin.path, "sub"],
            in: superRepo
        )
        try commit("add submodule", in: superRepo)
        return (container, superRepo)
    }

    // MARK: - Helpers

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

    /// Runs git without failing the test on a non-zero exit — used for the merge
    /// step that is *expected* to stop on conflicts.
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

extension GitStatusIntegrationTests {
    private func fetchSubmoduleEntry(in superRepo: URL) async throws -> ChangedFile {
        let files = try await makeProvider().fetchStatus(in: superRepo)
        return try XCTUnwrap(files.first { $0.path == "sub" })
    }
}
