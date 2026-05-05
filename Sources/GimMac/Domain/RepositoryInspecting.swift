import Foundation

protocol RepositoryInspecting: Sendable {
    func inspectRepository(at url: URL) async throws -> RepositoryState
}
