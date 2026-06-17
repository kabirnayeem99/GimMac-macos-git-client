import XCTest
@testable import GimMac

@MainActor
final class MotionStateTests: XCTestCase {
    func testSyncOutcomeUsesLatestResetTimer() async throws {
        let sut = makeViewModel()

        sut.signalSyncOutcome(.success)
        try await Task.sleep(for: .milliseconds(600))
        sut.signalSyncOutcome(.failure)
        try await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(sut.syncOutcome, .failure)

        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(sut.syncOutcome, .none)
    }

    func testCommitOutcomeResets() async throws {
        let sut = makeViewModel()

        sut.signalCommitOutcome(.success)
        XCTAssertEqual(sut.commitOutcome, .success)

        try await Task.sleep(for: .milliseconds(1_300))
        XCTAssertEqual(sut.commitOutcome, .none)
    }

    func testConflictContinueOutcomeResets() async throws {
        let sut = makeViewModel()

        sut.signalConflictContinueOutcome(.success)
        XCTAssertEqual(sut.conflictContinueOutcome, .success)

        try await Task.sleep(for: .milliseconds(1_300))
        XCTAssertEqual(sut.conflictContinueOutcome, .none)
    }

    func testRecentlyResolvedConflictAutoClears() async throws {
        let sut = makeViewModel()
        let file = ConflictedFileStatus.withMarkers(path: "File.swift", summary: .bothModified, conflictMarkerCount: 2)

        sut.signalRecentlyResolvedConflict(file)
        XCTAssertEqual(sut.recentlyResolvedConflict?.path, file.path)

        try await Task.sleep(for: .milliseconds(1_000))
        XCTAssertNil(sut.recentlyResolvedConflict)
    }

    func testChangedFilesSuppressInitialAndRepositoryReplacementAnimations() {
        let sut = ChangedFilesHandler()
        let firstRepository = [changedFile(path: "A.swift"), changedFile(path: "B.swift")]
        let secondRepository = [changedFile(path: "Other.swift")]

        sut.syncWith(firstRepository)
        XCTAssertFalse(sut.animatesNextFileChange)

        sut.syncWith(firstRepository + [changedFile(path: "C.swift")])
        XCTAssertTrue(sut.animatesNextFileChange)

        sut.syncWith(secondRepository)
        XCTAssertFalse(sut.animatesNextFileChange)

        sut.resetForRepositoryChange()
        sut.syncWith(firstRepository)
        XCTAssertFalse(sut.animatesNextFileChange)
    }

    func testChangedFileToggleTintAutoClears() async throws {
        let sut = ChangedFilesHandler()

        sut.toggle("A.swift")
        XCTAssertTrue(sut.recentlyToggled.contains("A.swift"))

        try await Task.sleep(for: .milliseconds(1_300))
        XCTAssertFalse(sut.recentlyToggled.contains("A.swift"))
    }

    private func changedFile(path: String) -> ChangedFile {
        ChangedFile(
            path: path,
            status: .modified,
            oldPath: nil,
            isStaged: false,
            hasConflict: false
        )
    }

    private func makeViewModel() -> RepositoryStoreViewModel {
        RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: MotionMockRepositoryInspector(),
            screenRepository: MotionMockScreenRepository(),
            diffProvider: MotionMockDiffProvider(),
            commitInspector: MotionMockCommitInspector(),
            commitProvider: MotionMockCommitProvider(),
            repositoryPersistence: MotionMockRepositoryPersistence()
        )
    }
}

private struct MotionMockRepositoryInspector: RepositoryInspecting, Sendable {
    func inspectRepository(at url: URL) async throws -> RepositoryInspectionResult { RepositoryInspectionResult(tip: .unknown) }
}

private struct MotionMockScreenRepository: RepositoryScreenDataProviding, Sendable {
    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot {
        RepositoryScreenSnapshot(
            changedFiles: [],
            commits: [],
            userProfile: GitUserProfile(name: "Test", email: "test@example.com"),
            primaryAction: .publishRepository,
            remoteName: nil,
            forcePushNeeded: false,
            unpushedSHAs: []
        )
    }

    func loadMoreCommits(for repository: Repository, skip: Int, maxCount: Int) async throws -> [Commit] { [] }
}

private struct MotionMockDiffProvider: DiffProviding, Sendable {
    func fetchDiff(in repositoryURL: URL, for path: String, oldPath: String?) async throws -> DiffDocument {
        DiffDocument(filePath: path, lines: [])
    }

    func fetchCommitDiff(in repositoryURL: URL, for path: String, commitSHA: String) async throws -> DiffDocument {
        DiffDocument(filePath: path, lines: [])
    }

    func submoduleDiff(in repositoryURL: URL, for changedFile: ChangedFile) async throws -> SubmoduleDiffData {
        SubmoduleDiffData(
            path: changedFile.path,
            fullPath: changedFile.path,
            oldSHA: nil,
            newSHA: nil,
            commitChanged: false,
            modifiedChanges: false,
            untrackedChanges: false
        )
    }

    func workingDirectoryImage(in repositoryURL: URL, for path: String) async throws -> ImageDiffContent {
        ImageDiffContent(mediaType: "image/png", base64Contents: "")
    }

    func blobImage(in repositoryURL: URL, for path: String, at ref: String) async throws -> ImageDiffContent {
        ImageDiffContent(mediaType: "image/png", base64Contents: "")
    }
}

private struct MotionMockCommitInspector: CommitInspecting, Sendable {
    func fetchFiles(for commitSHA: String, in repositoryURL: URL) async throws -> [CommitFile] { [] }
}

private struct MotionMockCommitProvider: CommitProviding, Sendable {
    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?,
        options: CommitOptions
    ) async throws {}

    func undoLastCommit(in repositoryURL: URL) async throws {}
}

private actor MotionMockRepositoryPersistence: RepositoryPersistenceProviding {
    func saveOrUpdateRepository(path: String) async throws -> StoredRepository {
        fatalError("Unused")
    }

    func getAllRepositoriesSortedByLastOpened() async throws -> [StoredRepository] { [] }
    func getCurrentlySelectedRepository() async throws -> StoredRepository? { nil }
    func selectRepository(id: UUID) async throws -> StoredRepository? { nil }
    func removeRepository(id: UUID) async throws {}
    func selectMostRecentlyOpenedRepositoryOnLaunch() async throws -> StoredRepository? { nil }
}
