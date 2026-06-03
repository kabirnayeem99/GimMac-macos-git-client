import Foundation

struct GitCommandResult: Sendable, Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol GitClientProtocol: Sendable {
    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult
    func run(_ arguments: [String], in repositoryURL: URL, extraEnvironment: [String: String], timeout: TimeInterval) async throws -> GitCommandResult
}

extension GitClientProtocol {
    func run(
        _ arguments: [String],
        in repositoryURL: URL,
        extraEnvironment: [String: String],
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        try await run(arguments, in: repositoryURL, timeout: timeout)
    }
}
