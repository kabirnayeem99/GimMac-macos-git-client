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

private actor MockRepositoryPersistence: RepositoryPersistenceProviding {
    var repositories: [StoredRepository]
    var selectedID: UUID?

    init(
        repositories: [StoredRepository] = [],
        selectedID: UUID? = nil
    ) {
        self.repositories = repositories
        self.selectedID = selectedID
    }

    func saveOrUpdateRepository(path: String) async throws -> StoredRepository {
        let canonicalPath = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let now = Date()
        if let idx = repositories.firstIndex(where: { $0.path == canonicalPath }) {
            let existing = repositories[idx]
            let updated = StoredRepository(
                id: existing.id,
                name: URL(fileURLWithPath: canonicalPath).lastPathComponent,
                path: canonicalPath,
                gitIdentifier: existing.gitIdentifier,
                currentlySelected: true,
                lastOpenedAt: now,
                createdAt: existing.createdAt,
                updatedAt: now,
                existsOnDisk: true
            )
            repositories = repositories.map { item in
                var next = item
                if next.id == updated.id {
                    next = updated
                } else if next.currentlySelected {
                    next = StoredRepository(
                        id: next.id,
                        name: next.name,
                        path: next.path,
                        gitIdentifier: next.gitIdentifier,
                        currentlySelected: false,
                        lastOpenedAt: next.lastOpenedAt,
                        createdAt: next.createdAt,
                        updatedAt: now,
                        existsOnDisk: next.existsOnDisk
                    )
                }
                return next
            }
            selectedID = updated.id
            return updated
        }

        let created = StoredRepository(
            id: UUID(),
            name: URL(fileURLWithPath: canonicalPath).lastPathComponent,
            path: canonicalPath,
            gitIdentifier: nil,
            currentlySelected: true,
            lastOpenedAt: now,
            createdAt: now,
            updatedAt: now,
            existsOnDisk: true
        )
        repositories = repositories.map {
            StoredRepository(
                id: $0.id,
                name: $0.name,
                path: $0.path,
                gitIdentifier: $0.gitIdentifier,
                currentlySelected: false,
                lastOpenedAt: $0.lastOpenedAt,
                createdAt: $0.createdAt,
                updatedAt: now,
                existsOnDisk: $0.existsOnDisk
            )
        } + [created]
        selectedID = created.id
        return created
    }

    func getAllRepositoriesSortedByLastOpened() async throws -> [StoredRepository] {
        repositories.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    func getCurrentlySelectedRepository() async throws -> StoredRepository? {
        repositories.first(where: { $0.currentlySelected })
    }

    func selectRepository(id: UUID) async throws -> StoredRepository? {
        guard let selected = repositories.first(where: { $0.id == id }) else {
            return nil
        }

        let now = Date()
        repositories = repositories.map { item in
            StoredRepository(
                id: item.id,
                name: item.name,
                path: item.path,
                gitIdentifier: item.gitIdentifier,
                currentlySelected: item.id == id,
                lastOpenedAt: item.id == id ? now : item.lastOpenedAt,
                createdAt: item.createdAt,
                updatedAt: now,
                existsOnDisk: item.existsOnDisk
            )
        }
        selectedID = selected.id
        return repositories.first(where: { $0.id == id })
    }

    func selectMostRecentlyOpenedRepositoryOnLaunch() async throws -> StoredRepository? {
        guard let chosen = repositories
            .sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt })
            .first(where: { $0.existsOnDisk }) else {
            return nil
        }
        return try await selectRepository(id: chosen.id)
    }
}

private struct MockCommitProvider: CommitProviding, Sendable {
    func commit(in repositoryURL: URL, paths: [String], summary: String, description: String?) async throws {}
}

private struct MockGitClient: GitClientProtocol, Sendable {
    let headByPath: [String: String]

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        if arguments == ["rev-parse", "HEAD"] {
            let value = headByPath[repositoryURL.path] ?? ""
            return GitCommandResult(stdout: value + "\n", stderr: "", exitCode: 0)
        }
        return GitCommandResult(stdout: "", stderr: "", exitCode: 0)
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
            diffProvider: MockDiffProvider(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
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
            diffProvider: MockDiffProvider(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
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

    func testBootstrapSelectsMostRecentExistingRepository() async {
        let older = Date().addingTimeInterval(-120)
        let newer = Date().addingTimeInterval(-60)
        let persistence = MockRepositoryPersistence(
            repositories: [
                StoredRepository(
                    id: UUID(),
                    name: "missing",
                    path: "/tmp/missing-repo",
                    gitIdentifier: nil,
                    currentlySelected: false,
                    lastOpenedAt: newer,
                    createdAt: older,
                    updatedAt: newer,
                    existsOnDisk: false
                ),
                StoredRepository(
                    id: UUID(),
                    name: "existing",
                    path: "/tmp/existing-repo",
                    gitIdentifier: nil,
                    currentlySelected: false,
                    lastOpenedAt: older,
                    createdAt: older,
                    updatedAt: older,
                    existsOnDisk: true
                )
            ]
        )

        let inspector = MockRepositoryInspector(result: .success(RepositoryState(currentBranch: "main", detachedHeadShortSHA: nil)))
        let sut = RepositoryStoreViewModel(
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: persistence
        )

        await sut.bootstrapRepositorySelectionOnLaunch()

        XCTAssertEqual(sut.selectedRepository?.url.path, "/tmp/existing-repo")
    }

    func testCoreDataPersistenceUpsertByPath() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let repoPath = tmp.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        let storeURL = tmp.appendingPathComponent("RepositoryStore.sqlite")
        let persistence = CoreDataRepositoryPersistence(
            gitClient: MockGitClient(headByPath: [repoPath.path: "abc123"]),
            storeURL: storeURL
        )

        _ = try await persistence.saveOrUpdateRepository(path: repoPath.path)
        _ = try await persistence.saveOrUpdateRepository(path: repoPath.path)
        let all = try await persistence.getAllRepositoriesSortedByLastOpened()

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].path, repoPath.path)
        XCTAssertEqual(all[0].gitIdentifier, "abc123")
    }

    func testCoreDataPersistenceSelectMostRecentSkipsMissing() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let existingRepo = tmp.appendingPathComponent("existing", isDirectory: true)
        try FileManager.default.createDirectory(at: existingRepo, withIntermediateDirectories: true)
        let missingRepo = tmp.appendingPathComponent("missing", isDirectory: true)

        let storeURL = tmp.appendingPathComponent("RepositoryStore.sqlite")
        let persistence = CoreDataRepositoryPersistence(
            gitClient: MockGitClient(headByPath: [:]),
            storeURL: storeURL
        )

        _ = try await persistence.saveOrUpdateRepository(path: existingRepo.path)
        _ = try await persistence.saveOrUpdateRepository(path: missingRepo.path)

        let selected = try await persistence.selectMostRecentlyOpenedRepositoryOnLaunch()

        XCTAssertEqual(selected?.path, existingRepo.path)
    }
}
