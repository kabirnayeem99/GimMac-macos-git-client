import XCTest
@testable import GimMac

/// Integration test for the negative push path: two clones of the same remote
/// diverge, the stale clone's plain push is rejected (non-fast-forward), and
/// it recovers via fetch + pull before a final push succeeds. This scenario —
/// the ordinary multi-collaborator case — had zero coverage anywhere in the
/// suite; every other remote-sync test only exercises the happy path.
///
/// SUT: `GitRemoteSyncService` (`fetch`/`pull`/`push`/`publishBranch`). No
/// dedicated error case exists for a non-fast-forward rejection (confirmed:
/// `GitAppErrorMapper` maps every unrecognized git failure to
/// `GitAppError.commandFailed`), so the assertion matches on the stderr
/// substring git itself reports ("rejected").
final class GitRemoteSyncIntegrationTests: XCTestCase {
    private let client = ProcessGitClient()

    func testStalePushIsRejectedThenRecoversViaFetchAndPull() async throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let originURL = parent.appendingPathComponent("origin.git", isDirectory: true)
        try runGit(["init", "--bare", originURL.path], in: parent)

        let syncService = GitRemoteSyncService(client: client)

        // workA clones first and publishes the initial commit.
        let workA = parent.appendingPathComponent("workA", isDirectory: true)
        try clone(from: originURL, to: workA)
        try configureIdentity(in: workA)
        try writeAndCommit("shared.txt", "base\n", message: "initial", in: workA)
        let branch = try currentBranch(in: workA)
        try await syncService.publishBranch(named: branch, remote: "origin", in: workA)

        // workB clones after workA's push (so it starts from the same state),
        // commits independently, and pushes first — this is what makes workA's
        // upcoming plain push stale.
        let workB = parent.appendingPathComponent("workB", isDirectory: true)
        try clone(from: originURL, to: workB)
        try configureIdentity(in: workB)
        try writeAndCommit("fromB.txt", "b work\n", message: "commit from B", in: workB)
        try await syncService.push(remote: "origin", in: workB)

        // workA, still unaware of B's push, commits and tries a plain push.
        try writeAndCommit("fromA.txt", "a work\n", message: "commit from A", in: workA)

        do {
            try await syncService.push(remote: "origin", in: workA)
            XCTFail("Expected a non-fast-forward push to be rejected")
        } catch let error as GitAppError {
            guard case let .commandFailed(_, _, _, stderr) = error else {
                return XCTFail("Expected .commandFailed, got \(error)")
            }
            XCTAssertTrue(
                stderr.lowercased().contains("rejected"),
                "Expected a non-fast-forward rejection, got: \(stderr)"
            )
        }

        // Recovery: fetch the remote's state, then pull (merge) it into workA,
        // then the same plain push that just failed must now succeed.
        try await syncService.fetch(remote: "origin", in: workA)
        // `pull` performs a merge by default; modern Git refuses to guess a
        // reconciliation strategy for genuinely divergent histories unless one
        // is configured, so pin it explicitly for a deterministic recovery.
        try runGit(["config", "pull.rebase", "false"], in: workA)
        try await syncService.pull(in: workA)
        try await syncService.push(remote: "origin", in: workA)

        let localLog = try runGitCapturing(["log", "--format=%H"], in: workA)
        let remoteLog = try runGitCapturing(["log", "--format=%H", branch], in: originURL)
        XCTAssertEqual(localLog, remoteLog)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workA.appendingPathComponent("fromB.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workA.appendingPathComponent("fromA.txt").path))
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func clone(from originURL: URL, to destination: URL) throws {
        try runGit(["clone", "--", originURL.path, destination.path], in: destination.deletingLastPathComponent())
    }

    private func configureIdentity(in root: URL) throws {
        try runGit(["config", "user.name", "Integration Test"], in: root)
        try runGit(["config", "user.email", "integration@test.local"], in: root)
        try runGit(["config", "commit.gpgsign", "false"], in: root)
    }

    private func currentBranch(in root: URL) throws -> String {
        try runGitCapturing(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writeAndCommit(_ fileName: String, _ contents: String, message: String, in root: URL) throws {
        try contents.write(to: root.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        try runGit(["add", "--", fileName], in: root)
        try runGit(["commit", "-m", message], in: root)
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
