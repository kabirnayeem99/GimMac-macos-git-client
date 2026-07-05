import Foundation

/// Implements `UpdateFromDefaultProviding` via `git merge` / `git rebase`.
/// Resolves the default branch the same way `GitBranchOperator` resolves
/// `.defaultBranch` start points: `origin/HEAD` first, then
/// `init.defaultBranch` config, then "main" as a hard fallback.
final class GitUpdateFromDefaultService: UpdateFromDefaultProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func mergeDefaultBranch(into branch: Branch, in repositoryURL: URL) async throws {
        let defaultBranch = try await resolveDefaultBranch(in: repositoryURL)
        _ = try await client.run(["merge", "--", defaultBranch], in: repositoryURL, timeout: 60)
    }

    func rebaseOntoDefaultBranch(_ branch: Branch, in repositoryURL: URL) async throws {
        let defaultBranch = try await resolveDefaultBranch(in: repositoryURL)
        _ = try await client.run(["rebase", "--", defaultBranch], in: repositoryURL, timeout: 120)
    }

    // MARK: - Default branch resolution

    private func resolveDefaultBranch(in repositoryURL: URL) async throws -> String {
        if let result = try? await client.run(
            ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
            in: repositoryURL,
            timeout: 5
        ) {
            let val = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !val.isEmpty { return val }
        }

        if let result = try? await client.run(
            ["config", "--get", "init.defaultBranch"],
            in: repositoryURL,
            timeout: 5
        ) {
            let val = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !val.isEmpty { return val }
        }

        return "main"
    }
}
