import Foundation

final class GitRemoteService: RepositoryRemoteProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchRemoteURL(named remote: String, in repositoryURL: URL) async throws -> String? {
        do {
            let result = try await client.run(
                ["remote", "get-url", "--", remote],
                in: repositoryURL,
                timeout: 5
            )
            let url = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return url.isEmpty ? nil : url
        } catch let err as GitAppError {
            // exit 2 = remote does not exist
            if case .commandFailed(_, let code, _, _) = err, code == 2 {
                return nil
            }
            throw err
        }
    }

    func setRemoteURL(_ url: String, named remote: String, in repositoryURL: URL) async throws {
        _ = try await client.run(
            ["remote", "set-url", "--", remote, url],
            in: repositoryURL,
            timeout: 10
        )
    }
}
