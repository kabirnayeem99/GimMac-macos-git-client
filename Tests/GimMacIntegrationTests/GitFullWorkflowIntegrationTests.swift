import XCTest
@testable import GimMac

/// End-to-end integration test covering a continuous Git workflow through the
/// app's own service layer. Exercises clone, commit, rename, push, squash,
/// force-push, tag, delete, and a final push against a local bare remote.
final class GitFullWorkflowIntegrationTests: XCTestCase {
    func testFullGitWorkflow_cloneModifyRenamePushSquashTagDelete() async throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let originURL = parent.appendingPathComponent("origin.git", isDirectory: true)
        let workDir = parent.appendingPathComponent("work", isDirectory: true)
        try runGit(["init", "--bare", originURL.path], in: parent)

        let client = ProcessGitClient()
        let cloneService = GitRepositoryCloneService(client: client)
        let commitProvider = GitCommitProvider(client: client, logger: GimMacLogger())
        let syncService = GitRemoteSyncService(client: client)
        let squashProvider = GitSquashProvider(client: client)
        let tagProvider = GitTagProvider(client: client)

        // Step 1 — clone
        try await cloneService.clone(from: originURL.path, to: workDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDir.appendingPathComponent(".git").path))

        // Step 0b — identity (must happen after workDir exists)
        try runGit(["config", "user.name", "Integration Test"], in: workDir)
        try runGit(["config", "user.email", "integration@test.local"], in: workDir)
        try runGit(["config", "commit.gpgsign", "false"], in: workDir)

        // Step 2 — save
        let notesURL = workDir.appendingPathComponent("notes.txt")
        try "hello\n".write(to: notesURL, atomically: true, encoding: .utf8)
        try await commitProvider.commit(
            in: workDir, paths: ["notes.txt"], summary: "Add notes",
            description: nil, options: CommitOptions()
        )
        XCTAssertEqual(try commitCount(in: workDir), 1)

        // Step 3 — modify
        try "hello world\n".write(to: notesURL, atomically: true, encoding: .utf8)
        try await commitProvider.commit(
            in: workDir, paths: ["notes.txt"], summary: "Update notes",
            description: nil, options: CommitOptions()
        )
        XCTAssertEqual(try commitCount(in: workDir), 2)

        // Step 4 — move #1
        _ = try await client.run(["mv", "--", "notes.txt", "journal.txt"], in: workDir, timeout: 15)
        try await commitProvider.commit(
            in: workDir, paths: ["notes.txt", "journal.txt"], summary: "Rename notes.txt to journal.txt",
            description: nil, options: CommitOptions()
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: notesURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDir.appendingPathComponent("journal.txt").path))

        // Step 5 — move #2
        _ = try await client.run(["mv", "--", "journal.txt", "diary.txt"], in: workDir, timeout: 15)
        try await commitProvider.commit(
            in: workDir, paths: ["journal.txt", "diary.txt"], summary: "Rename journal.txt to diary.txt",
            description: nil, options: CommitOptions()
        )
        let diaryURL = workDir.appendingPathComponent("diary.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: diaryURL.path))
        XCTAssertEqual(try commitCount(in: workDir), 4)

        // Step 6 — push
        let branch = try runGitCapturing(["rev-parse", "--abbrev-ref", "HEAD"], in: workDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try await syncService.publishBranch(named: branch, remote: "origin", in: workDir)
        let localHead = try headSHA(in: workDir)
        let remoteHead = try runGitCapturing(["rev-parse", branch], in: originURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(localHead, remoteHead)

        // Step 7 — squash last 3 commits (Update notes + both renames), keep "Add notes" as base
        let shaLog = try runGitCapturing(["log", "--format=%H", "-n", "3"], in: workDir)
        let shas = shaLog.split(separator: "\n").map(String.init)
        let commitsToSquash = shas.map { sha in
            Commit(
                id: sha,
                shortHash: String(sha.prefix(7)),
                authorName: "x",
                authorEmail: "x@x",
                date: Date(timeIntervalSince1970: 0),
                summary: "x",
                body: nil
            )
        }
        try await squashProvider.squash(commits: commitsToSquash, message: "Squash update+renames", in: workDir)
        XCTAssertEqual(try commitCount(in: workDir), 2)
        // squashed-away commits are no longer reachable from HEAD
        for sha in shas.dropLast() {
            let result = try? await client.run(["merge-base", "--is-ancestor", sha, "HEAD"], in: workDir, timeout: 10)
            XCTAssertNotEqual(result?.exitCode, 0)
        }

        // Step 8 — re-sync remote (history was rewritten under an already-pushed branch)
        try await syncService.pushForceSafely(remote: "origin", in: workDir)
        let remoteHeadAfterSquash = try runGitCapturing(["rev-parse", branch], in: originURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let localHeadAfterSquash = try headSHA(in: workDir)
        XCTAssertEqual(remoteHeadAfterSquash, localHeadAfterSquash)

        // Step 9 — tag
        let headCommit = Commit(
            id: localHeadAfterSquash,
            shortHash: String(localHeadAfterSquash.prefix(7)),
            authorName: "x",
            authorEmail: "x@x",
            date: Date(timeIntervalSince1970: 0),
            summary: "x",
            body: nil
        )
        try await tagProvider.createTag(named: "v1.0.0", message: "Release 1.0.0", at: headCommit, in: workDir)
        let taggedSHA = try runGitCapturing(["rev-list", "-n", "1", "v1.0.0"], in: workDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(taggedSHA, localHeadAfterSquash)

        // Step 10 — delete
        try FileManager.default.removeItem(at: diaryURL)
        try await commitProvider.commit(
            in: workDir, paths: ["diary.txt"], summary: "Delete diary.txt",
            description: nil, options: CommitOptions()
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: diaryURL.path))
        let status = try await client.run(["status", "--porcelain"], in: workDir, timeout: 10)
        XCTAssertEqual(status.stdout, "")
        XCTAssertEqual(try commitCount(in: workDir), 3)

        // Step 11 — final push, full round-trip check
        try await syncService.push(remote: "origin", in: workDir)
        let localLog = try runGitCapturing(["log", "--format=%H"], in: workDir)
        let remoteLog = try runGitCapturing(["log", "--format=%H", branch], in: originURL)
        XCTAssertEqual(localLog, remoteLog)
        // tag was never pushed (by design) — confirm it does not exist on the remote
        let remoteTagCheck = try? await client.run(["tag", "--list", "v1.0.0"], in: originURL, timeout: 10)
        XCTAssertEqual(remoteTagCheck?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }

    // MARK: - Helpers (duplicated per existing repo convention, see other files in this target)

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
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

    private func commitCount(in root: URL) throws -> Int {
        let output = try runGitCapturing(["rev-list", "--count", "HEAD"], in: root)
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
    }

    private func headSHA(in root: URL) throws -> String {
        try runGitCapturing(["rev-parse", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
