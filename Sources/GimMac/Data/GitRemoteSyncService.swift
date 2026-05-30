import Foundation

final class GitRemoteSyncService: RemoteSyncProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetch(remote: String, in repositoryURL: URL) async throws {
        _ = try await client.run(["fetch", remote], in: repositoryURL, timeout: 60)
    }

    func pull(in repositoryURL: URL) async throws {
        _ = try await client.run(["pull"], in: repositoryURL, timeout: 120)
    }

    func push(remote: String, in repositoryURL: URL) async throws {
        _ = try await client.run(["push", remote], in: repositoryURL, timeout: 60)
    }

    func pushForceSafely(remote: String, in repositoryURL: URL) async throws {
        _ = try await client.run(["push", "--force-with-lease", remote], in: repositoryURL, timeout: 60)
    }

    func publishBranch(named branch: String, remote: String, in repositoryURL: URL) async throws {
        _ = try await client.run(
            ["push", "--set-upstream", remote, branch],
            in: repositoryURL,
            timeout: 60
        )
    }
}
