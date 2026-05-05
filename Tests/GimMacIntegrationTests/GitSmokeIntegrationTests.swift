import Foundation
import XCTest
@testable import GimMac

final class GitSmokeIntegrationTests: XCTestCase {
    func testTemporaryRepositoryCanInitialize() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let process = Process()
        process.currentDirectoryURL = tempDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "init"]

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, "git init failed: \(errText)")
    }

    func testRepositoryInspectorReadsCurrentBranch() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        try runGit(["init"], in: tempDir)
        let readme = tempDir.appendingPathComponent("README.txt")
        try "phase1".data(using: .utf8)?.write(to: readme)
        try runGit(["add", "--", "README.txt"], in: tempDir)
        try runGit(["-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false", "commit", "-m", "init"], in: tempDir)
        try runGit(["checkout", "-b", "phase1-test"], in: tempDir)

        let inspector = LocalGitRepositoryInspector()
        let state = try await inspector.inspectRepository(at: tempDir)

        XCTAssertEqual(state.currentBranch, "phase1-test")
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
