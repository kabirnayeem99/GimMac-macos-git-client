import Foundation

final class GitHistoryProvider: HistoryProviding, Sendable {
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

final class GitStatusProvider: StatusProviding, Sendable {
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

final class GitCommitProvider: CommitProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?,
        options: CommitOptions
    ) async throws {
        let normalizedPaths = Array(Set(paths)).sorted()
        guard options.isAmend || !normalizedPaths.isEmpty else {
            return
        }

        if !normalizedPaths.isEmpty {
            _ = try await client.run(["add", "-A", "--"] + normalizedPaths, in: repositoryURL, timeout: 15)
        }

        var commitArguments = ["commit", "-m", summary]
        if let description, !description.isEmpty {
            commitArguments += ["-m", description]
        }
        if options.isAmend {
            commitArguments.append("--amend")
        }
        if options.skipHooks {
            commitArguments.append("--no-verify")
        }
        if options.signOff {
            commitArguments.append("--signoff")
        }
        if !normalizedPaths.isEmpty {
            commitArguments += ["--"] + normalizedPaths
        }

        _ = try await client.run(commitArguments, in: repositoryURL, timeout: 20)
    }

    func undoLastCommit(in repositoryURL: URL) async throws {
        _ = try await client.run(["reset", "--soft", "HEAD~1"], in: repositoryURL, timeout: 15)
    }
}

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
}

final class GitStashProvider: StashProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchStash(in repositoryURL: URL) async throws -> StashEntry? {
        let format = "%gd%x00%s%x00%gD"
        let result = try await client.run(
            ["stash", "list", "-n", "1", "--format=\(format)"],
            in: repositoryURL,
            timeout: 10
        )
        let line = result.stdout.split(separator: "\n").first.map(String.init) ?? ""
        guard !line.isEmpty else { return nil }
        let parts = line.components(separatedBy: "\0")
        guard parts.count >= 2 else { return nil }
        let id = parts[0]
        let message = parts[1]
        // Try to parse "WIP on <branch>: ..." from the message
        let branchName = Self.parseBranchName(from: message) ?? ""
        return StashEntry(id: id, message: message, branchName: branchName)
    }

    func applyStash(in repositoryURL: URL) async throws {
        _ = try await client.run(["stash", "pop"], in: repositoryURL, timeout: 30)
    }

    func dropStash(in repositoryURL: URL) async throws {
        _ = try await client.run(["stash", "drop"], in: repositoryURL, timeout: 10)
    }

    private static func parseBranchName(from message: String) -> String? {
        // "WIP on branch: ..." or "On branch: ..."
        let scanners = ["WIP on ", "On "]
        for prefix in scanners {
            if message.hasPrefix(prefix) {
                let rest = message.dropFirst(prefix.count)
                if let colon = rest.firstIndex(of: ":") {
                    return String(rest[..<colon])
                }
            }
        }
        return nil
    }
}
