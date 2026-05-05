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
