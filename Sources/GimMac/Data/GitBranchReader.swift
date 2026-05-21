import Foundation

/// Implements `BranchProviding` over `git for-each-ref` / `git branch`.
///
/// All shell-style arguments are passed as `[String]` arrays — never as shell
/// strings — per the security model in `AGENTS.md`.
final class GitBranchReader: BranchProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchBranches(in repositoryURL: URL) async throws -> [Branch] {
        let arguments = [
            "for-each-ref",
            "--format=\(BranchForEachRefParser.formatString)",
            "refs/heads",
            "refs/remotes"
        ]
        let result = try await client.run(arguments, in: repositoryURL, timeout: 15)
        return BranchForEachRefParser.parse(result.stdout)
    }

    func fetchBranchesPointing(at commitish: String, in repositoryURL: URL) async throws -> [Branch] {
        let result = try await client.run(
            ["branch", "--points-at=\(commitish)", "--format=%(refname:short)"],
            in: repositoryURL,
            timeout: 10
        )
        let names = result.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if names.isEmpty { return [] }
        let all = try await fetchBranches(in: repositoryURL)
        let nameSet = Set(names)
        return all.filter { nameSet.contains($0.name) }
    }

    func fetchMergedBranches(into branch: Branch, in repositoryURL: URL) async throws -> [Branch] {
        let result = try await client.run(
            ["branch", "--merged", branch.name, "--format=%(refname:short)"],
            in: repositoryURL,
            timeout: 10
        )
        let names = result.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { name -> String in
                // `git branch --merged` prefixes the current branch with "* "
                if name.hasPrefix("* ") { return String(name.dropFirst(2)) }
                return name
            }
            .filter { !$0.isEmpty }

        if names.isEmpty { return [] }
        let all = try await fetchBranches(in: repositoryURL)
        let nameSet = Set(names)
        return all.filter { $0.isLocal && nameSet.contains($0.name) }
    }
}
