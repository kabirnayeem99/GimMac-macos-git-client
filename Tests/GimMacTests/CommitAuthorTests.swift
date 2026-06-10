import XCTest
@testable import GimMac

final class CommitAuthorTests: XCTestCase {
    func testParseValidToken() {
        let author = CommitAuthor.parse("Jane Doe <jane@example.com>")
        XCTAssertEqual(author, CommitAuthor(name: "Jane Doe", email: "jane@example.com"))
    }

    func testParseTrimsWhitespace() {
        let author = CommitAuthor.parse("  Jane Doe   <  jane@example.com  >  ")
        XCTAssertEqual(author, CommitAuthor(name: "Jane Doe", email: "jane@example.com"))
    }

    func testParseRejectsMissingAngleBrackets() {
        XCTAssertNil(CommitAuthor.parse("Jane Doe jane@example.com"))
    }

    func testParseRejectsMissingName() {
        XCTAssertNil(CommitAuthor.parse("<jane@example.com>"))
    }

    func testParseRejectsEmailWithoutAtSign() {
        XCTAssertNil(CommitAuthor.parse("Jane Doe <not-an-email>"))
    }

    func testTrailerLineFormat() {
        let author = CommitAuthor(name: "Jane Doe", email: "jane@example.com")
        XCTAssertEqual(author.trailerLine, "Co-authored-by: Jane Doe <jane@example.com>")
    }
}
