import XCTest
@testable import GimMac

final class GitIgnoreProviderTests: XCTestCase {
    private var repoURL: URL!
    private var gitignoreURL: URL!
    private let sut = GitIgnoreProvider()

    override func setUpWithError() throws {
        repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-gitignore-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        gitignoreURL = repoURL.appendingPathComponent(".gitignore")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: repoURL)
    }

    private func readGitignore() throws -> String {
        try String(contentsOf: gitignoreURL, encoding: .utf8)
    }

    func testCreatesGitignoreWhenAbsent() async throws {
        try await sut.appendIgnoreEntries(["*.log"], in: repoURL)
        XCTAssertEqual(try readGitignore(), "*.log\n")
    }

    func testAppendsToExistingFilePreservingContent() async throws {
        try "node_modules/\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
        try await sut.appendIgnoreEntries(["*.log"], in: repoURL)
        XCTAssertEqual(try readGitignore(), "node_modules/\n*.log\n")
    }

    func testAddsMissingTrailingNewlineBeforeAppending() async throws {
        try "node_modules/".write(to: gitignoreURL, atomically: true, encoding: .utf8)
        try await sut.appendIgnoreEntries(["*.log"], in: repoURL)
        XCTAssertEqual(try readGitignore(), "node_modules/\n*.log\n")
    }

    func testDeduplicatesAgainstExistingRules() async throws {
        try "*.log\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
        try await sut.appendIgnoreEntries(["*.log", "*.tmp"], in: repoURL)
        XCTAssertEqual(try readGitignore(), "*.log\n*.tmp\n")
    }

    func testNoOpWhenAllEntriesAlreadyPresent() async throws {
        try "*.log\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
        try await sut.appendIgnoreEntries(["*.log"], in: repoURL)
        XCTAssertEqual(try readGitignore(), "*.log\n")
    }

    func testIgnoresEmptyAndWhitespaceOnlyEntries() async throws {
        try await sut.appendIgnoreEntries(["   ", ""], in: repoURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: gitignoreURL.path))
    }
}
