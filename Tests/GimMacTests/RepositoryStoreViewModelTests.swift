import Foundation
import XCTest
@testable import GimMac

private struct MockRepositoryInspector: RepositoryInspecting, Sendable {
    let result: Result<RepositoryState, Error>

    func inspectRepository(at url: URL) async throws -> RepositoryState {
        try result.get()
    }
}

@MainActor
final class RepositoryStoreViewModelTests: XCTestCase {
    func testSelectRepositorySuccessUpdatesBranch() async {
        let inspector = MockRepositoryInspector(
            result: .success(RepositoryState(currentBranch: "main", detachedHeadShortSHA: nil))
        )
        let sut = RepositoryStoreViewModel(inspector: inspector)

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))

        XCTAssertEqual(sut.repositoryState.branchDisplayText, "main")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testSelectRepositoryFailureSetsError() async {
        enum TestError: Error { case failed }
        let inspector = MockRepositoryInspector(result: .failure(TestError.failed))
        let sut = RepositoryStoreViewModel(inspector: inspector)

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))

        XCTAssertEqual(sut.repositoryState.branchDisplayText, "No repository selected")
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testDetachedHeadDisplayFormatting() {
        let state = RepositoryState(currentBranch: nil, detachedHeadShortSHA: "abc1234")
        XCTAssertEqual(state.branchDisplayText, "HEAD (detached @ abc1234)")
    }
}
