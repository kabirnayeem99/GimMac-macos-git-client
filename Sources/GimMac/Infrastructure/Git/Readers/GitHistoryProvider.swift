import Foundation

/// Fetches commit history by driving `git log` with the parser's format string.
/// Keeps history retrieval isolated from working-tree/status concerns.
final class GitHistoryProvider: HistoryProviding, Sendable {
    private static let defaultMaxCount = 200
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchHistory(in repositoryURL: URL, maxCount: Int?, skip: Int) async throws -> [Commit] {
        var arguments = ["log", "--format=\(GitLogParser.logFormat)"]
        arguments.append("-n")
        arguments.append("\(maxCount ?? Self.defaultMaxCount)")
        if skip > 0 {
            arguments.append("--skip=\(skip)")
        }

        let result = try await client.run(arguments, in: repositoryURL, timeout: 15)
        return GitLogParser.parse(result.stdout)
    }
}
