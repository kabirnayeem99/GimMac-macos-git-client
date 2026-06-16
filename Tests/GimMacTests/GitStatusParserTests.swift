import XCTest
@testable import GimMac

/// Unit coverage for `GitStatusParser` porcelain v2 `-z` parsing, focused on the
/// untracked/ignored marker handling that previously assumed `? <path>` had no
/// leading-space paths (audit Issue 11).
final class GitStatusParserTests: XCTestCase {
    /// Joins porcelain v2 records the way `git status --porcelain=v2 -z` does.
    private func porcelain(_ records: [String]) -> String {
        records.joined(separator: "\u{0}") + "\u{0}"
    }

    func testUntrackedPathBeginningWithSpaceIsPreserved() {
        // Record is `?` + single separator space + path. The path itself starts
        // with a space, so the result must keep exactly that leading space.
        let files = GitStatusParser.parse(porcelain(["?  spaced name.txt"]))

        XCTAssertEqual(files.count, 1)
        let file = files.first
        XCTAssertEqual(file?.path, " spaced name.txt")
        XCTAssertEqual(file?.status, .untracked)
        XCTAssertEqual(file?.isStaged, false)
    }

    func testUntrackedAndIgnoredClassifiedFromMarker() {
        let files = GitStatusParser.parse(porcelain(["? new.txt", "! build/output.o"]))

        XCTAssertEqual(files.map(\.path), ["new.txt", "build/output.o"])
        XCTAssertEqual(files.map(\.status), [.untracked, .ignored])
    }

    func testUntrackedPathWithInteriorSpacesIsPreserved() {
        let files = GitStatusParser.parse(porcelain(["? My Documents/a b c.txt"]))

        XCTAssertEqual(files.first?.path, "My Documents/a b c.txt")
        XCTAssertEqual(files.first?.status, .untracked)
    }

    func testMarkerWithoutSeparatorIsIgnored() {
        // A bare `?` with no separator space is malformed and must not yield an
        // empty-path entry.
        let files = GitStatusParser.parse(porcelain(["?"]))
        XCTAssertTrue(files.isEmpty)
    }

    func testOrdinaryModifiedStillParses() {
        // Sanity: ordinary records keep working alongside the marker change.
        let record = "1 .M N... 100644 100644 100644 1111111 2222222 file.txt"
        let files = GitStatusParser.parse(porcelain([record]))

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.path, "file.txt")
        XCTAssertEqual(files.first?.status, .modified)
        XCTAssertEqual(files.first?.isStaged, false)
    }
}
