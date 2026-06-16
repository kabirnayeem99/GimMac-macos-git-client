import XCTest
@testable import GimMac

/// Returns a fixed HEAD hash without touching git, so persistence tests do not
/// depend on a real repository.
private actor FixedHeadClient: GitClientProtocol {
    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        GitCommandResult(stdout: "deadbeefdeadbeef\n", stderr: "", exitCode: 0)
    }
}

/// Verifies the store load no longer aborts the process on a corrupt SQLite file
/// and recovers into a usable store (audit crash risk).
final class CoreDataPersistenceRecoveryTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testCorruptStoreRecoversWithoutCrashing() async throws {
        let storeURL = tempDir.appendingPathComponent("RepositoryStore.sqlite")
        // Garbage where a SQLite database is expected — loadPersistentStores fails.
        try Data("this is not a sqlite database".utf8).write(to: storeURL)

        // Initialization must not assertionFailure; it destroys and reloads the store.
        let sut = CoreDataRepositoryPersistence(
            gitClient: FixedHeadClient(),
            storeURL: storeURL,
            inMemory: false
        )

        // The recovered store is usable for reads and writes.
        let repoPath = tempDir.appendingPathComponent("repo", isDirectory: true).path
        let stored = try await sut.saveOrUpdateRepository(path: repoPath)
        XCTAssertEqual(stored.name, "repo")

        let all = try await sut.getAllRepositoriesSortedByLastOpened()
        XCTAssertEqual(all.count, 1)
    }
}
