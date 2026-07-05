import Foundation

/// Creates lightweight or annotated tags at a specific commit.
final class GitTagProvider: TagProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func createTag(named name: String, message: String?, at commit: Commit, in repositoryURL: URL) async throws {
        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let arguments: [String] = trimmedMessage.isEmpty
            ? ["tag", "--", name, commit.id]
            : ["tag", "-a", "-m", trimmedMessage, "--", name, commit.id]
        _ = try await client.run(arguments, in: repositoryURL, timeout: 15)
    }
}
