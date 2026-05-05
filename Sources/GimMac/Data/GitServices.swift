import Foundation

final class GitHistoryProvider: HistoryProviding, @unchecked Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchHistory(in repositoryURL: URL, maxCount: Int?) async throws -> [Commit] {
        var arguments = ["log", "--format=\(GitLogParser.logFormat)"]
        if let maxCount = maxCount {
            arguments.append("-n")
            arguments.append("\(maxCount)")
        }

        let result = try await client.run(arguments, in: repositoryURL, timeout: 15)
        return GitLogParser.parse(result.stdout)
    }
}

final class GitStatusProvider: StatusProviding, @unchecked Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile] {
        let arguments = ["status", "--porcelain=v1", "-uall"]
        let result = try await client.run(arguments, in: repositoryURL, timeout: 10)
        return GitStatusParser.parse(result.stdout)
    }
}
