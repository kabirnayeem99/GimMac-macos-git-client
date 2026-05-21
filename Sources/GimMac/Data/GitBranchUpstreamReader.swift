import Foundation

final class GitBranchUpstreamReader: BranchUpstreamProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchUpstream(for branch: String, in repositoryURL: URL) async throws -> String? {
        let result = try await client.run(
            ["for-each-ref", "--format=%(upstream:short)", "refs/heads/\(branch)"],
            in: repositoryURL,
            timeout: 5
        )
        let upstream = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return upstream.isEmpty ? nil : upstream
    }
}
