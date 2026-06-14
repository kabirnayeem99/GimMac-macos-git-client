import XCTest
@testable import GimMac

/// Unit tests for `RepositoryBranchDisplayFormatter`.
///
/// Guards the invariant that `TipState.detached` carries the *full* SHA in the
/// model (matching GitHub Desktop's `IDetachedHead.currentSha`) while the
/// branch UI shows the abbreviated 7-char form.
final class RepositoryBranchDisplayFormatterTests: XCTestCase {
    func testDetachedShowsAbbreviatedShaEvenWhenModelHoldsFullSha() {
        let fullSHA = "2acb028231d408aaa865f9538b1c89de5a2b9da8"
        let text = RepositoryBranchDisplayFormatter.displayText(for: .detached(sha: fullSHA))
        XCTAssertEqual(text, "HEAD @ 2acb028")
    }

    func testValidShowsBranchName() {
        let text = RepositoryBranchDisplayFormatter.displayText(
            for: .valid(branch: BranchSummary(name: "feature/foo", upstream: nil, sha: "abc"))
        )
        XCTAssertEqual(text, "feature/foo")
    }

    func testUnbornShowsRef() {
        XCTAssertEqual(RepositoryBranchDisplayFormatter.displayText(for: .unborn(ref: "master")), "master")
    }

    func testUnknownShowsPlaceholder() {
        XCTAssertEqual(RepositoryBranchDisplayFormatter.displayText(for: .unknown), "No repository selected")
    }
}
