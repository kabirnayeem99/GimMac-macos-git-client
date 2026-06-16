import Foundation

/// Resets the current branch HEAD to a target commit with the requested mode.
final class GitResetProvider: ResetProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func reset(to commit: Commit, mode: ResetMode, in repositoryURL: URL) async throws {
        let flag: String
        switch mode {
        case .soft: flag = "--soft"
        case .mixed: flag = "--mixed"
        case .hard: flag = "--hard"
        }
        _ = try await client.run(["reset", flag, commit.id], in: repositoryURL, timeout: 30)
    }
}
