import XCTest
@testable import GimMac

final class GitIgnoreRuleTests: XCTestCase {
    func testEscapeEscapesGitSpecialCharacters() {
        XCTAssertEqual(GitIgnoreRule.escape("a[b]!c*d#e?f"), "a\\[b\\]\\!c\\*d\\#e\\?f")
    }

    func testEscapeLeavesOrdinaryPathUntouched() {
        XCTAssertEqual(GitIgnoreRule.escape("src/main/App.swift"), "src/main/App.swift")
    }

    func testFileRuleEscapesPath() {
        XCTAssertEqual(GitIgnoreRule.fileRule(forRelativePath: "build/[cache].log"), "build/\\[cache\\].log")
    }

    func testFolderRuleAppendsTrailingSlash() {
        XCTAssertEqual(GitIgnoreRule.folderRule(forRelativePath: "node_modules"), "node_modules/")
    }

    func testExtensionRuleKeepsLeadingGlob() {
        XCTAssertEqual(GitIgnoreRule.extensionRule(forExtension: "log"), "*.log")
    }

    func testAncestorFoldersImmediateParentFirst() {
        XCTAssertEqual(
            GitIgnoreRule.ancestorFolders(ofRelativePath: "a/b/c/file.txt"),
            ["a/b/c", "a/b", "a"]
        )
    }

    func testAncestorFoldersEmptyForRootFile() {
        XCTAssertEqual(GitIgnoreRule.ancestorFolders(ofRelativePath: "file.txt"), [])
    }

    func testFileExtensionFromLastComponent() {
        XCTAssertEqual(GitIgnoreRule.fileExtension(ofRelativePath: "src/App.swift"), "swift")
    }

    func testFileExtensionNilWhenNoExtension() {
        XCTAssertNil(GitIgnoreRule.fileExtension(ofRelativePath: "src/Makefile"))
    }

    func testFileExtensionNilForDotfile() {
        XCTAssertNil(GitIgnoreRule.fileExtension(ofRelativePath: ".gitignore"))
    }
}
