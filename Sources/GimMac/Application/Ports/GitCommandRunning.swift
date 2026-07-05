import Foundation

/// Abstraction over the low-level Git process runner so `ProcessGitClient` can
/// be tested with fake runners and real execution can be swapped.
protocol GitCommandRunning: Sendable {
    func execute(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> GitCommandResult
    func executeData(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> Data
    func cancel(id: UUID) async
    func cancelAll() async
}

extension GitCommandRunning {
    /// Fallback: decode the text result's stdout. Real runners override this to
    /// preserve raw bytes.
    func executeData(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> Data {
        Data(try await execute(id: id, arguments: arguments, repositoryURL: repositoryURL, extraEnvironment: extraEnvironment).stdout.utf8)
    }

    func cancelAll() async {}
}
