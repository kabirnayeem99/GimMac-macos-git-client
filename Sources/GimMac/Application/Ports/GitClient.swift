import Foundation

/// Result of running a Git command. Kept alongside `GitClient` because the
/// command contract depends on this shape.
struct GitCommandResult: Sendable, Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol GitClientProtocol: Sendable {
    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult
    func run(
        _ arguments: [String],
        in repositoryURL: URL,
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> GitCommandResult
    func run(_ arguments: [String], in repositoryURL: URL, extraEnvironment: [String: String], timeout: TimeInterval) async throws -> GitCommandResult
    /// Runs a command capturing stdout as raw bytes — required for binary output
    /// (e.g. image blobs via `git show`) where UTF-8 decoding would corrupt data.
    func runReturningData(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> Data
    func runReturningData(
        _ arguments: [String],
        in repositoryURL: URL,
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> Data
}

extension GitClientProtocol {
    func run(
        _ arguments: [String],
        in repositoryURL: URL,
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        try await run(arguments, in: repositoryURL, timeout: timeout)
    }

    func run(
        _ arguments: [String],
        in repositoryURL: URL,
        extraEnvironment: [String: String],
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        try await run(arguments, in: repositoryURL, timeout: timeout)
    }

    /// Fallback for conformers that only capture text (e.g. test doubles). The
    /// real `ProcessGitClient` overrides this to capture raw bytes losslessly.
    func runReturningData(
        _ arguments: [String],
        in repositoryURL: URL,
        timeout: TimeInterval
    ) async throws -> Data {
        Data(try await run(arguments, in: repositoryURL, timeout: timeout).stdout.utf8)
    }

    func runReturningData(
        _ arguments: [String],
        in repositoryURL: URL,
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> Data {
        try await runReturningData(arguments, in: repositoryURL, timeout: timeout)
    }
}
