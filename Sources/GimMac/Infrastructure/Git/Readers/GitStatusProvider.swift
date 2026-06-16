import Foundation

/// Fetches the working-tree status using the porcelain v2 format, which is
/// machine-readable and stable across Git versions.
final class GitStatusProvider: StatusProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile] {
        let arguments = ["status", "--porcelain=v2", "--untracked-files=all", "-z"]
        let result = try await client.run(arguments, in: repositoryURL, timeout: 10)
        return GitStatusParser.parse(result.stdout).sorted {
            $0.path.lowercased() < $1.path.lowercased()
        }
    }
}
