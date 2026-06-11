import XCTest
@testable import GimMac

/// Exercises `GitConfigService` against a real `git` process with `HOME` pinned
/// to a temporary directory, so the developer's actual `~/.gitconfig` is never
/// read or written.
final class GitConfigServiceIntegrationTests: XCTestCase {
    private var home: URL!
    private var sut: GitConfigService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        sut = GitConfigService(client: ProcessGitClient(), homeURL: home)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
        home = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testReadsNilWhenUnset() async throws {
        let name = try await sut.globalUserName()
        let branch = try await sut.globalDefaultBranch()
        XCTAssertNil(name)
        XCTAssertNil(branch)
    }

    func testUserNameRoundTrip() async throws {
        try await sut.setGlobalUserName("Ada Lovelace")
        let name = try await sut.globalUserName()
        XCTAssertEqual(name, "Ada Lovelace")
    }

    func testDefaultBranchRoundTrip() async throws {
        try await sut.setGlobalDefaultBranch("trunk")
        let branch = try await sut.globalDefaultBranch()
        XCTAssertEqual(branch, "trunk")
    }

    func testWritesToIsolatedHomeNotRealHome() async throws {
        try await sut.setGlobalDefaultBranch("trunk")
        // The value must live in the temporary HOME's .gitconfig.
        let configFile = home.appendingPathComponent(".gitconfig")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFile.path))
        let contents = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(contents.contains("trunk"))
    }
}
