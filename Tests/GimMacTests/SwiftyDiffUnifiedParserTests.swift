import XCTest
@testable import GimMac

final class SwiftyDiffUnifiedParserTests: XCTestCase {
    func testParsePreservesPathsContainingSpaces() {
        let diff = """
        diff --git a/folder old/file name.txt b/folder new/file name.txt
        index 1111111..2222222 100644
        --- a/folder old/file name.txt
        +++ b/folder new/file name.txt
        @@ -1 +1 @@
        -old
        +new
        """

        let files = SwiftyDiffUnifiedParser.parse(diff)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.oldPath, "folder old/file name.txt")
        XCTAssertEqual(files.first?.path, "folder new/file name.txt")
    }
}
