import XCTest
@testable import GimMac

final class GitCommandBuilderTests: XCTestCase {
    func testRevParseHeadShortCommand() {
        XCTAssertEqual(GitCommandBuilder.revParseHeadShort(), ["rev-parse", "--short", "HEAD"])
    }

    func testWithPathAppendsSeparatorAndPath() {
        XCTAssertEqual(
            GitCommandBuilder.withPath(["diff"], path: "Sources/GimMac/main.swift"),
            ["diff", "--", "Sources/GimMac/main.swift"]
        )
    }
}
