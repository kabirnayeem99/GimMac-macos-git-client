import XCTest
@testable import GimMac

final class BundledRepositoryTemplateCatalogTests: XCTestCase {
    private var templatesRoot: URL!

    override func setUpWithError() throws {
        templatesRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-catalog-tests-\(UUID().uuidString)", isDirectory: true)
        let gitIgnore = templatesRoot.appendingPathComponent("GitIgnore", isDirectory: true)
        let licenses = templatesRoot.appendingPathComponent("Licenses", isDirectory: true)
        try FileManager.default.createDirectory(at: gitIgnore, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: licenses, withIntermediateDirectories: true)

        try "build/\n".write(to: gitIgnore.appendingPathComponent("Swift.gitignore"), atomically: true, encoding: .utf8)
        try "node_modules/\n".write(to: gitIgnore.appendingPathComponent("Node.gitignore"), atomically: true, encoding: .utf8)
        // A non-template file that must be ignored.
        try "noise".write(to: gitIgnore.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)

        let manifest = """
        [
          { "name": "Zed License", "featured": false, "file": "zed.txt" },
          { "name": "Apache License", "featured": true, "file": "apache.txt" }
        ]
        """
        try manifest.write(to: licenses.appendingPathComponent("licenses.json"), atomically: true, encoding: .utf8)
        try "ZED BODY".write(to: licenses.appendingPathComponent("zed.txt"), atomically: true, encoding: .utf8)
        try "APACHE BODY".write(to: licenses.appendingPathComponent("apache.txt"), atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: templatesRoot)
    }

    private func makeSUT() -> BundledRepositoryTemplateCatalog {
        BundledRepositoryTemplateCatalog(templatesRootOverride: templatesRoot)
    }

    func testListsGitIgnoreNamesSortedAndIgnoresNonTemplates() async {
        let names = await makeSUT().gitIgnoreTemplateNames()
        XCTAssertEqual(names, ["Node", "Swift"])
    }

    func testReadsGitIgnoreContents() async throws {
        let contents = try await makeSUT().gitIgnoreTemplate(named: "Swift")
        XCTAssertEqual(contents, "build/\n")
    }

    func testUnknownGitIgnoreThrows() async {
        do {
            _ = try await makeSUT().gitIgnoreTemplate(named: "DoesNotExist")
            XCTFail("Expected an error for an unknown template")
        } catch let error as GitAppError {
            guard case .scaffoldingFailed = error else {
                return XCTFail("Expected .scaffoldingFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected GitAppError, got \(error)")
        }
    }

    func testLicensesAreFeaturedFirstThenAlphabetical() async {
        let licenses = await makeSUT().licenses()
        XCTAssertEqual(licenses.map(\.name), ["Apache License", "Zed License"])
        XCTAssertEqual(licenses.first?.featured, true)
        XCTAssertEqual(licenses.first?.body, "APACHE BODY")
    }
}
