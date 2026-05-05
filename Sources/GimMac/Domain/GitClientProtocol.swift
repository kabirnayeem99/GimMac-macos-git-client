import Foundation

struct GitCommandResult: Sendable, Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol GitClientProtocol: Sendable {
    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult
}
