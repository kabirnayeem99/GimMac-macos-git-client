import XCTest
@testable import GimMac

final class GitLogParserTests: XCTestCase {
    func testParsePreservesPipeCharactersInCommitSummary() {
        let output = [
            "",
            "abc123\(GitLogParser.fieldSeparator)abc123\(GitLogParser.fieldSeparator)Kabir\(GitLogParser.fieldSeparator)kabir@example.com\(GitLogParser.fieldSeparator)1720000000\(GitLogParser.fieldSeparator)subject with | pipes | intact\(GitLogParser.fieldSeparator)",
            "def456\(GitLogParser.fieldSeparator)def456\(GitLogParser.fieldSeparator)Kabir\(GitLogParser.fieldSeparator)kabir@example.com\(GitLogParser.fieldSeparator)1720000001\(GitLogParser.fieldSeparator)plain subject\(GitLogParser.fieldSeparator)"
        ].joined(separator: GitLogParser.recordSeparator)

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.map(\.summary), ["subject with | pipes | intact", "plain subject"])
    }

    func testParsePopulatesCommitBody() {
        let output = "abc123\(GitLogParser.fieldSeparator)abc123\(GitLogParser.fieldSeparator)Kabir\(GitLogParser.fieldSeparator)kabir@example.com\(GitLogParser.fieldSeparator)1720000000\(GitLogParser.fieldSeparator)subject\(GitLogParser.fieldSeparator)first body line\nsecond body line\n"

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.map(\.body), ["first body line\nsecond body line"])
    }

    func testParseTreatsEmptyBodyAsNil() {
        let output = "abc123\(GitLogParser.fieldSeparator)abc123\(GitLogParser.fieldSeparator)Kabir\(GitLogParser.fieldSeparator)kabir@example.com\(GitLogParser.fieldSeparator)1720000000\(GitLogParser.fieldSeparator)subject\(GitLogParser.fieldSeparator)"

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.map(\.body), [nil])
    }
}
