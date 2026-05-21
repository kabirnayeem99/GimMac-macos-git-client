import Foundation

protocol HistoryProviding: Sendable {
    func fetchHistory(in repositoryURL: URL, maxCount: Int?) async throws -> [Commit]
}

protocol StatusProviding: Sendable {
    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile]
}

protocol DiffProviding: Sendable {
    func fetchDiff(in repositoryURL: URL, for path: String) async throws -> DiffDocument
}

protocol CommitProviding: Sendable {
    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?
    ) async throws
}

protocol RepositoryPersistenceProviding: Sendable {
    func saveOrUpdateRepository(path: String) async throws -> StoredRepository
    func getAllRepositoriesSortedByLastOpened() async throws -> [StoredRepository]
    func getCurrentlySelectedRepository() async throws -> StoredRepository?
    func selectRepository(id: UUID) async throws -> StoredRepository?
    func selectMostRecentlyOpenedRepositoryOnLaunch() async throws -> StoredRepository?
}

protocol RepositoryScreenDataProviding: Sendable {
    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot
}

protocol BranchUpstreamProviding: Sendable {
    func fetchUpstream(for branch: String, in repositoryURL: URL) async throws -> String?
}
