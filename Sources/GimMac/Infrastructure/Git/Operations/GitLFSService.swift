import Foundation

final class GitLFSService: LFSProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func isLFSAvailable(in repositoryURL: URL) async throws -> Bool {
        do {
            _ = try await client.run(["lfs", "version"], in: repositoryURL, timeout: 5)
            return true
        } catch {
            return false
        }
    }

    func initializeLFS(in repositoryURL: URL) async throws {
        _ = try await client.run(["lfs", "install"], in: repositoryURL, timeout: 15)
    }
}
