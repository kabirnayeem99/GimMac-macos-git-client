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

final class GitCommitProvider: CommitProviding, @unchecked Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?
    ) async throws {
        let normalizedPaths = Array(Set(paths)).sorted()
        guard !normalizedPaths.isEmpty else {
            return
        }

        _ = try await client.run(["add", "-A", "--"] + normalizedPaths, in: repositoryURL, timeout: 15)

        var commitArguments = ["commit", "-m", summary]
        if let description, !description.isEmpty {
            commitArguments += ["-m", description]
        }
        commitArguments += ["--"] + normalizedPaths

        _ = try await client.run(commitArguments, in: repositoryURL, timeout: 20)
    }
}
