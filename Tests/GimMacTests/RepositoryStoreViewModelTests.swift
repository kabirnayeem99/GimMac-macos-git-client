import Foundation
import XCTest
@testable import GimMac

private struct MockRepositoryInspector: RepositoryInspecting, Sendable {
    let result: Result<RepositoryState, Error>

    func inspectRepository(at url: URL) async throws -> RepositoryState {
        try result.get()
    }
}

private struct MockRepositoryScreenDataProvider: RepositoryScreenDataProviding, Sendable {
    let snapshot: RepositoryScreenSnapshot

    func loadSnapshot(for repository: Repository?) async -> RepositoryScreenSnapshot {
        snapshot
    }
}

private struct MockDiffProvider: DiffProviding, Sendable {
    func fetchDiff(in repositoryURL: URL, for path: String) async throws -> DiffDocument {
        DiffDocument(filePath: path, lines: [])
    }
}

private extension RepositoryScreenSnapshot {
    static var testSnapshot: RepositoryScreenSnapshot {
        RepositoryScreenSnapshot(
            changedFiles: [],
            commits: [],
            userProfile: GitUserProfile(name: "Test User", email: "test@example.com"),
            primaryAction: .fetch,
            hasRemote: false
        )
    }
}

@MainActor
final class RepositoryStoreViewModelTests: XCTestCase {
    func testSelectRepositorySuccessUpdatesBranch() async {
        let inspector = MockRepositoryInspector(
            result: .success(RepositoryState(currentBranch: "main", detachedHeadShortSHA: nil))
        )
        let sut = RepositoryStoreViewModel(
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider()
        )

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))

        XCTAssertEqual(RepositoryBranchDisplayFormatter.displayText(for: sut.repositoryState), "main")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testSelectRepositoryFailureSetsError() async {
        enum TestError: Error { case failed }
        let inspector = MockRepositoryInspector(result: .failure(TestError.failed))
        let sut = RepositoryStoreViewModel(
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider()
        )

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))

        XCTAssertEqual(
            RepositoryBranchDisplayFormatter.displayText(for: sut.repositoryState),
            "No repository selected"
        )
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testDetachedHeadDisplayFormatting() {
        let state = RepositoryState(currentBranch: nil, detachedHeadShortSHA: "abc1234")
        XCTAssertEqual(
            RepositoryBranchDisplayFormatter.displayText(for: state),
            "HEAD (detached @ abc1234)"
        )
    }
}
