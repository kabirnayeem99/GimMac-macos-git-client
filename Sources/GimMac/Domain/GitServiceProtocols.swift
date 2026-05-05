import Foundation

protocol HistoryProviding: Sendable {
    func fetchHistory(in repositoryURL: URL, maxCount: Int?) async throws -> [Commit]
}

protocol StatusProviding: Sendable {
    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile]
}
