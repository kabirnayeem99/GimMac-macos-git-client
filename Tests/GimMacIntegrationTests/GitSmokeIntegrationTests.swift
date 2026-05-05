import XCTest
@testable import GimMac

final class GitSmokeIntegrationTests: XCTestCase {
    func testInspectRepositoryReturnsBranchForNamedBranch() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try runGit(["init"], in: root)
        try runGit(["checkout", "-b", "phase1-test"], in: root)

        let sut = LocalGitRepositoryInspector()
        let state = try await sut.inspectRepository(at: root)

        XCTAssertEqual(state.currentBranch, "phase1-test")
    }

    func testProcessGitClientRevParseAndStatusInRealRepository() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try runGit(["init"], in: root)
        let readmeURL = root.appendingPathComponent("README.md")
        try "hello".write(to: readmeURL, atomically: true, encoding: .utf8)
        try runGit(["add", "--", "README.md"], in: root)
        try runGit([
            "-c", "user.name=Test",
            "-c", "user.email=test@example.com",
            "-c", "commit.gpgsign=false",
            "commit", "-m", "initial"
        ], in: root)

        let sut = ProcessGitClient()

        let revParse = try await sut.run(GitCommandBuilder.revParseHeadShort(), in: root, timeout: 10)
        XCTAssertFalse(revParse.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let status = try await sut.run(GitCommandBuilder.statusPorcelainV1(), in: root, timeout: 10)
        XCTAssertEqual(status.stdout, "")
        XCTAssertEqual(status.exitCode, 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = tempRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func runGit(_ args: [String], in directory: URL) throws {
        let process = Process()
        process.currentDirectoryURL = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("git \(args.joined(separator: " ")) failed: \(err)")
        }
    }
}
