import XCTest
@testable import GimMac

final class GitLogParserTests: XCTestCase {
    func testParsePreservesPipeCharactersInCommitSummary() {
        let output = [
            "",
            "abc123\(GitLogParser.fieldSeparator)abc123\(GitLogParser.fieldSeparator)Kabir\(GitLogParser.fieldSeparator)kabir@example.com\(GitLogParser.fieldSeparator)1720000000\(GitLogParser.fieldSeparator)subject with | pipes | intact",
            "def456\(GitLogParser.fieldSeparator)def456\(GitLogParser.fieldSeparator)Kabir\(GitLogParser.fieldSeparator)kabir@example.com\(GitLogParser.fieldSeparator)1720000001\(GitLogParser.fieldSeparator)plain subject"
        ].joined(separator: GitLogParser.recordSeparator)

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.map(\.summary), ["subject with | pipes | intact", "plain subject"])
    }
}
