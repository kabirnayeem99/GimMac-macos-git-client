import XCTest
@testable import GimMac

final class GitCommandBuilderTests: XCTestCase {
    func testRevParseHeadShortCommand() {
        XCTAssertEqual(GitCommandBuilder.revParseHeadShort(), ["rev-parse", "--short", "HEAD"])
    }

    func testStatusPorcelainV1Command() {
        XCTAssertEqual(GitCommandBuilder.statusPorcelainV1(), ["status", "--porcelain=v1", "-z"])
    }

    func testWithPathAppendsSeparatorAndPath() {
        XCTAssertEqual(
            GitCommandBuilder.withPath(["diff"], path: "Sources/GimMac/main.swift"),
            ["diff", "--", "Sources/GimMac/main.swift"]
        )
    }
}
