import XCTest
@testable import GimMac

/// Integration tests for `GitDiffProvider` against real temporary repositories.
/// Mirrors the *conditions* of GitHub Desktop's
/// `app/test/unit/git/diff-test.ts` `getWorkingDirectoryDiff` group, adapted to
/// GimMac's API and reduced to the diff surface GimMac actually implements.
///
/// SUT: `GitDiffProvider.fetchDiff(in:for:oldPath:)` (combined `git diff -M` +
/// `git diff --cached -M -- <paths>`) and `fetchCommitDiff(in:for:commitSHA:)`.
///
/// `DiffDocument` flattens hunks into a single `[DiffDocumentLine]` and does
/// NOT carry the `@@` header as a line (GitHub Desktop keeps the header as
/// `hunk.lines[0]`). Assertions here index content lines directly.
///
/// Behavior notes vs the reference:
///
/// 1. **Pure rename has no content hunks**, matching the reference, *when the
///    old path is supplied*. `fetchDiff` includes both old and new paths in the
///    pathspec with `-M`, so Git's rename detection pairs them. `DiffHandler`
///    passes `ChangedFile.oldPath`. (`testPureRenameHasNoHunks`.)
///
/// 2. **Unborn-repo files are shown as pure additions**, matching the
///    reference. With no HEAD to diff against, `fetchDiff` renders the working
///    tree via `git diff --no-index -- /dev/null <path>`.
///    (`testUnbornRepositoryMixedStateShowsAddedLinesOnly`.)
///
/// Now covered: binary diffs (`DiffContentKind.binary`), image diffs
/// (`workingDirectoryImage` / `blobImage` / `fetchDiff` → `.image`), and
/// submodule diffs (`submoduleDiff` → `SubmoduleDiffData`).
///
/// Reference cases still with NO GimMac equivalent (reported as gaps, not tested
/// here): `getBinaryPaths` (binary-path listing), `getBranchMergeBaseChangedFiles`
/// / `getBranchMergeBaseDiff` (merge-base diff), and LF→CRLF line-ending capture
/// (no line-ending model).
final class GitDiffIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    private var sut: GitDiffProvider { GitDiffProvider(client: client) }

    // MARK: - getWorkingDirectoryDiff

    /// Reference: "counts lines for new file". A new file must be staged for
    /// GimMac to diff it (`git diff` does not show untracked files); the staged
    /// diff captures the additions.
    func testNewFileCountsAddedLines() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try write("new.md", "l1\nl2\nl3\n", in: root)
        try runGit(["add", "--", "new.md"], in: root)

        let diff = try await sut.fetchDiff(in: root, for: "new.md")

        XCTAssertEqual(diff.addedCount, 3)
        XCTAssertEqual(diff.removedCount, 0)
        XCTAssertEqual(diff.lines.map(\.text), ["l1", "l2", "l3"])
        XCTAssertTrue(diff.lines.allSatisfy { $0.kind == .added })
    }

    /// Reference: "counts lines for modified file" — a tracked file edited in
    /// the working tree shows context + additions.
    func testModifiedFileShowsContextAndAddition() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try write("a.txt", "base\nadded line\n", in: root)

        let diff = try await sut.fetchDiff(in: root, for: "a.txt")

        XCTAssertEqual(diff.addedCount, 1)
        XCTAssertEqual(diff.removedCount, 0)
        XCTAssertEqual(diff.lines.first?.kind, .context)
        XCTAssertEqual(diff.lines.first?.text, "base")
        XCTAssertEqual(diff.lines.last?.kind, .added)
        XCTAssertEqual(diff.lines.last?.text, "added line")
    }

    /// Reference: "counts lines for staged file" — a change in the index (after
    /// `git add`) is captured via `git diff --cached`.
    func testStagedFileShowsStagedChange() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try write("a.txt", "base\nstaged line\n", in: root)
        try runGit(["add", "--", "a.txt"], in: root)

        let diff = try await sut.fetchDiff(in: root, for: "a.txt")

        XCTAssertEqual(diff.addedCount, 1)
        XCTAssertEqual(diff.lines.last?.kind, .added)
        XCTAssertEqual(diff.lines.last?.text, "staged line")
    }

    /// Reference: "is empty for a renamed file" (0 hunks). Passing the rename's
    /// old path lets Git pair the two paths and report a pure rename with no
    /// content hunks.
    func testPureRenameHasNoHunks() async throws {
        let root = try makeCommittedRepository(fileName: "foo", contents: "foo\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try runGit(["mv", "foo", "bar"], in: root)

        let diff = try await sut.fetchDiff(in: root, for: "bar", oldPath: "foo")

        XCTAssertTrue(diff.lines.isEmpty)
    }

    /// Reference: "only shows modifications after move for a renamed and
    /// modified file" — the unstaged (post-move edit) diff wins the merge, so
    /// the result is the modification, not a pure addition.
    func testRenamedAndModifiedFileShowsModification() async throws {
        let root = try makeCommittedRepository(fileName: "foo", contents: "foo\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try runGit(["mv", "foo", "bar"], in: root)
        try write("bar", "bar\n", in: root)

        let diff = try await sut.fetchDiff(in: root, for: "bar", oldPath: "foo")

        XCTAssertEqual(diff.removedCount, 1)
        XCTAssertEqual(diff.addedCount, 1)
        XCTAssertEqual(diff.lines.map(\.text), ["foo", "bar"])
        XCTAssertEqual(diff.lines.map(\.kind), [.removed, .added])
    }

    /// Reference: "handles unborn repository with mixed state" — the working
    /// tree is shown as a pure addition (note #2).
    func testUnbornRepositoryMixedStateShowsAddedLinesOnly() async throws {
        let root = try makeEmptyRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("foo", "WRITING THE FIRST LINE\n", in: root)
        try runGit(["add", "--", "foo"], in: root)
        try write("foo", "WRITING OVER THE TOP\n", in: root)

        let diff = try await sut.fetchDiff(in: root, for: "foo")

        XCTAssertEqual(diff.lines.map(\.kind), [.added])
        XCTAssertEqual(diff.lines.map(\.text), ["WRITING OVER THE TOP"])
    }

    /// Reference: "displays unicode characters" — multi-byte content survives
    /// the diff round-trip intact.
    func testUnicodeCharactersPreservedInDiff() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try write("u.txt", "café 😀 你好\n", in: root)
        try runGit(["add", "--", "u.txt"], in: root)

        let diff = try await sut.fetchDiff(in: root, for: "u.txt")

        XCTAssertEqual(diff.lines.map(\.text), ["café 😀 你好"])
    }

    // MARK: - binary

    /// Reference: "displays a binary diff for a docx file" (`DiffType.Binary`).
    /// Git reports binary content as a one-line summary; `fetchDiff` flags it.
    func testBinaryFileDiffIsFlaggedBinary() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0x00, 0x42])
        try data.write(to: root.appendingPathComponent("blob.bin"))
        try runGit(["add", "--", "blob.bin"], in: root)

        let diff = try await sut.fetchDiff(in: root, for: "blob.bin")

        XCTAssertTrue(diff.isBinary)
        XCTAssertEqual(diff.kind, .binary)
        XCTAssertTrue(diff.lines.isEmpty)
    }

    // MARK: - image (getWorkingDirectoryImage / getBlobImage / imageDiff)

    /// PNG signature + a non-UTF-8 byte (0xFF) to prove the raw-bytes path does
    /// not corrupt binary content.
    private let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0xFF, 0x10, 0x42])
    private let pngBytesModified = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0xFE, 0x20, 0x43, 0x44])

    /// Reference: "getWorkingDirectoryImage retrieves valid image for new file".
    func testWorkingDirectoryImageReadsBytesAndMediaType() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "base\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try pngBytes.write(to: root.appendingPathComponent("new-image.png"))

        let image = try await sut.workingDirectoryImage(in: root, for: "new-image.png")

        XCTAssertEqual(image.mediaType, "image/png")
        XCTAssertEqual(image.base64Contents, pngBytes.base64EncodedString())
    }

    /// Reference: "getBlobImage retrieves valid image for modified file" — reads
    /// the committed blob losslessly via the raw-bytes git path.
    func testBlobImageReadsCommittedBytesLosslessly() async throws {
        let root = try makeEmptyRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try pngBytes.write(to: root.appendingPathComponent("img.png"))
        try runGit(["add", "--", "img.png"], in: root)
        try commit("add image", in: root)
        // Change the working copy so HEAD still holds the original bytes.
        try pngBytesModified.write(to: root.appendingPathComponent("img.png"))

        let blob = try await sut.blobImage(in: root, for: "img.png", at: "HEAD")

        XCTAssertEqual(blob.mediaType, "image/png")
        XCTAssertEqual(blob.base64Contents, pngBytes.base64EncodedString())
    }

    /// Reference: "imageDiff changes for images are set" — a modified image
    /// yields an image diff with both previous and current sides.
    func testModifiedImageProducesImageDiffWithBothSides() async throws {
        let root = try makeEmptyRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try pngBytes.write(to: root.appendingPathComponent("img.png"))
        try runGit(["add", "--", "img.png"], in: root)
        try commit("add image", in: root)
        try pngBytesModified.write(to: root.appendingPathComponent("img.png"))

        let diff = try await sut.fetchDiff(in: root, for: "img.png")

        guard case let .image(data) = diff.kind else {
            return XCTFail("Expected .image kind, got \(diff.kind)")
        }
        XCTAssertEqual(data.previous?.base64Contents, pngBytes.base64EncodedString())
        XCTAssertEqual(data.current?.base64Contents, pngBytesModified.base64EncodedString())
    }

    /// Reference: "getBlobImage retrieves valid images for deleted file" — a
    /// deleted image has a previous side but no current side.
    func testDeletedImageHasPreviousButNoCurrent() async throws {
        let root = try makeEmptyRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try pngBytes.write(to: root.appendingPathComponent("img.png"))
        try runGit(["add", "--", "img.png"], in: root)
        try commit("add image", in: root)
        try runGit(["rm", "--", "img.png"], in: root)

        let diff = try await sut.fetchDiff(in: root, for: "img.png")

        guard case let .image(data) = diff.kind else {
            return XCTFail("Expected .image kind, got \(diff.kind)")
        }
        XCTAssertEqual(data.previous?.base64Contents, pngBytes.base64EncodedString())
        XCTAssertNil(data.current)
    }

    // MARK: - submodule

    /// Reference: "can get the diff for a submodule with the right paths".
    func testSubmoduleDiffReportsPaths() async throws {
        let (root, sub) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: sub) }
        try write("README.md", "hello\n", in: submodule(of: root))

        let diff = try await submoduleDiff(in: root)

        XCTAssertEqual(diff.path, "foo/submodule")
        XCTAssertEqual(diff.fullPath, root.appendingPathComponent("foo/submodule").path)
    }

    /// Reference: "with only modified changes".
    func testSubmoduleModifiedOnly() async throws {
        let (root, sub) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: sub) }
        try write("README.md", "hello\n", in: submodule(of: root))

        let diff = try await submoduleDiff(in: root)

        XCTAssertNil(diff.oldSHA)
        XCTAssertNil(diff.newSHA)
        XCTAssertFalse(diff.commitChanged)
        XCTAssertTrue(diff.modifiedChanges)
        XCTAssertFalse(diff.untrackedChanges)
    }

    /// Reference: "with only untracked changes".
    func testSubmoduleUntrackedOnly() async throws {
        let (root, sub) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: sub) }
        try write("NEW.md", "hello\n", in: submodule(of: root))

        let diff = try await submoduleDiff(in: root)

        XCTAssertNil(diff.oldSHA)
        XCTAssertNil(diff.newSHA)
        XCTAssertFalse(diff.commitChanged)
        XCTAssertFalse(diff.modifiedChanges)
        XCTAssertTrue(diff.untrackedChanges)
    }

    /// Reference: "with a commit change".
    func testSubmoduleCommitChange() async throws {
        let (root, sub) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: sub) }
        let subDir = submodule(of: root)
        try write("README.md", "hello\n", in: subDir)
        try commitAll("sub commit", in: subDir)

        let diff = try await submoduleDiff(in: root)

        XCTAssertNotNil(diff.oldSHA)
        XCTAssertNotNil(diff.newSHA)
        XCTAssertNotEqual(diff.oldSHA, diff.newSHA)
        XCTAssertTrue(diff.commitChanged)
        XCTAssertFalse(diff.modifiedChanges)
        XCTAssertFalse(diff.untrackedChanges)
    }

    /// Reference: "all kinds of changes".
    func testSubmoduleAllChanges() async throws {
        let (root, sub) = try makeSuperRepoWithSubmodule()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: sub) }
        let subDir = submodule(of: root)
        try write("README.md", "hello\n", in: subDir)
        try commitAll("sub commit", in: subDir)
        try write("README.md", "bye\n", in: subDir)
        try write("NEW.md", "new!!\n", in: subDir)

        let diff = try await submoduleDiff(in: root)

        XCTAssertNotNil(diff.oldSHA)
        XCTAssertNotNil(diff.newSHA)
        XCTAssertTrue(diff.commitChanged)
        XCTAssertTrue(diff.modifiedChanges)
        XCTAssertTrue(diff.untrackedChanges)
    }

    // MARK: - fetchCommitDiff

    /// The root commit has no parent; `fetchCommitDiff` falls back to `git show`
    /// and reports the file's contents as additions.
    func testFetchCommitDiffForRootCommitShowsAdditions() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "one\ntwo\n")
        defer { try? FileManager.default.removeItem(at: root) }
        let sha = try revParse("HEAD", in: root)

        let diff = try await sut.fetchCommitDiff(in: root, for: "a.txt", commitSHA: sha)

        XCTAssertEqual(diff.addedCount, 2)
        XCTAssertEqual(diff.lines.map(\.text), ["one", "two"])
    }

    /// A non-root commit diffs `parent..commit` and reports just that commit's
    /// change to the file.
    func testFetchCommitDiffForChildCommitShowsModification() async throws {
        let root = try makeCommittedRepository(fileName: "a.txt", contents: "one\n")
        defer { try? FileManager.default.removeItem(at: root) }
        try write("a.txt", "one\ntwo\n", in: root)
        try runGit(["add", "--", "a.txt"], in: root)
        try commit("add two", in: root)
        let sha = try revParse("HEAD", in: root)

        let diff = try await sut.fetchCommitDiff(in: root, for: "a.txt", commitSHA: sha)

        XCTAssertEqual(diff.addedCount, 1)
        XCTAssertEqual(diff.lines.last?.text, "two")
        XCTAssertEqual(diff.lines.last?.kind, .added)
    }

}

// MARK: - Helpers

extension GitDiffIntegrationTests {

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

    /// Creates a superproject with a `foo/submodule` gitlink. Returns
    /// (superproject, submodule-origin) — both temp dirs the caller cleans up.
    private func makeSuperRepoWithSubmodule() throws -> (root: URL, sub: URL) {
        let sub = try makeCommittedRepository(fileName: "README.md", contents: "readme\n")
        let root = try makeCommittedRepository(fileName: "top.txt", contents: "top\n")
        // `protocol.file.allow=always` is required to add a submodule from a
        // local path under modern Git.
        try runGit(["-c", "protocol.file.allow=always", "submodule", "add", sub.path, "foo/submodule"], in: root)
        try commit("add submodule", in: root)
        return (root, sub)
    }

    private func submodule(of root: URL) -> URL {
        root.appendingPathComponent("foo/submodule")
    }

    /// Fetches real status, locates the `foo/submodule` change, and returns its
    /// computed submodule diff.
    private func submoduleDiff(in root: URL) async throws -> SubmoduleDiffData {
        let files = try await GitStatusProvider(client: client).fetchStatus(in: root)
        let file = try XCTUnwrap(files.first { $0.path == "foo/submodule" })
        return try await sut.submoduleDiff(in: root, for: file)
    }

    private func write(_ fileName: String, _ contents: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    /// Stages all changes then commits — for repos where files were written
    /// but not individually `git add`-ed (e.g. inside a submodule).
    private func commitAll(_ message: String, in root: URL) throws {
        try runGit(["add", "-A"], in: root)
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

    private func revParse(_ rev: String, in root: URL) throws -> String {
        try runGitCapturing(["rev-parse", rev], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
