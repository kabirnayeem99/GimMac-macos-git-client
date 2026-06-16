import Foundation

/// Reads and manipulates the Git stash list.
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
        return StashEntry(id: id, index: 0, message: message, branchName: branchName)
    }

    func fetchAllStashes(in repositoryURL: URL) async throws -> [StashEntry] {
        // `%gd` = stash selector (stash@{N}), `%s` = subject, `%ct` = commit time.
        // NUL-delimited fields so messages may contain anything but NUL.
        let format = "%gd%x00%s%x00%ct"
        let result = try await client.run(
            ["stash", "list", "--format=\(format)"],
            in: repositoryURL,
            timeout: 10
        )
        return result.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { Self.parseStashLine(String($0)) }
    }

    private static func parseStashLine(_ line: String) -> StashEntry? {
        let parts = line.components(separatedBy: "\0")
        guard parts.count >= 2 else { return nil }
        let selector = parts[0]
        let message = parts[1]
        let createdAt = parts.count >= 3
            ? TimeInterval(parts[2]).map { Date(timeIntervalSince1970: $0) }
            : nil
        return StashEntry(
            id: selector,
            index: parseStashIndex(from: selector),
            message: message,
            branchName: parseBranchName(from: message) ?? "",
            createdAt: createdAt
        )
    }

    /// Pull the `N` out of `stash@{N}`. Defaults to 0 when absent.
    private static func parseStashIndex(from selector: String) -> Int {
        guard let open = selector.lastIndex(of: "{"),
              let close = selector.lastIndex(of: "}"),
              open < close else { return 0 }
        let inner = selector[selector.index(after: open)..<close]
        return Int(inner) ?? 0
    }

    func applyStash(in repositoryURL: URL) async throws {
        _ = try await client.run(["stash", "pop"], in: repositoryURL, timeout: 30)
    }

    func dropStash(in repositoryURL: URL) async throws {
        _ = try await client.run(["stash", "drop"], in: repositoryURL, timeout: 10)
    }

    func applyStash(in repositoryURL: URL, ref: String) async throws {
        _ = try await client.run(["stash", "apply", ref], in: repositoryURL, timeout: 30)
    }

    func popStash(in repositoryURL: URL, ref: String) async throws {
        _ = try await client.run(["stash", "pop", ref], in: repositoryURL, timeout: 30)
    }

    func dropStash(in repositoryURL: URL, ref: String) async throws {
        _ = try await client.run(["stash", "drop", ref], in: repositoryURL, timeout: 10)
    }

    func pushStash(in repositoryURL: URL, message: String?) async throws {
        var arguments = ["stash", "push", "--include-untracked"]
        if let message, !message.isEmpty {
            arguments += ["-m", message]
        }
        _ = try await client.run(arguments, in: repositoryURL, timeout: 30)
    }

    private static func parseBranchName(from message: String) -> String? {
        // "WIP on branch: ..." or "On branch: ..."
        let scanners = ["WIP on ", "On "]
        for prefix in scanners where message.hasPrefix(prefix) {
            let rest = message.dropFirst(prefix.count)
            if let colon = rest.firstIndex(of: ":") {
                return String(rest[..<colon])
            }
        }
        return nil
    }
}
