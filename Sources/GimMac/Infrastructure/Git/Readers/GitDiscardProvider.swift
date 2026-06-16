import Foundation

/// Discards working-tree changes, choosing `git clean` for untracked files and
/// `git checkout HEAD` for tracked modifications.
final class GitDiscardProvider: DiscardProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func discardChanges(in repositoryURL: URL, for path: String, status: GitFileStatus) async throws {
        let arguments: [String]
        switch status {
        case .untracked, .ignored:
            arguments = ["clean", "-f", "--", path]
        default:
            arguments = ["checkout", "HEAD", "--", path]
        }
        _ = try await client.run(arguments, in: repositoryURL, timeout: 15)
    }

    func discardAllChanges(in repositoryURL: URL) async throws {
        // Revert tracked changes (staged + unstaged), then remove untracked
        // files and directories. Two steps because `reset --hard` leaves
        // untracked files in place.
        _ = try await client.run(["reset", "--hard", "HEAD"], in: repositoryURL, timeout: 30)
        _ = try await client.run(["clean", "-fd"], in: repositoryURL, timeout: 30)
    }
}
