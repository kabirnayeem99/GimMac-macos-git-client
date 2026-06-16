import Foundation

/// `git init` for new repositories. Mirrors GitHub Desktop's `init.ts`, which
/// passes `-c init.defaultBranch=<resolved>` so the first branch name honours
/// the user's global config.
final class GitRepositoryInitService: RepositoryInitProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func initRepository(at directoryURL: URL) async throws {
        let defaultBranch = await resolveDefaultBranch(at: directoryURL)
        _ = try await client.run(
            ["-c", "init.defaultBranch=\(defaultBranch)", "init"],
            in: directoryURL,
            timeout: 15
        )
    }

    /// Read `init.defaultBranch` from global config; fall back to "main".
    private func resolveDefaultBranch(at directoryURL: URL) async -> String {
        if let result = try? await client.run(
            ["config", "--global", "--get", "init.defaultBranch"],
            in: directoryURL,
            timeout: 5
        ) {
            let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return "main"
    }
}

/// `git clone` for remote repositories. Mirrors GitHub Desktop's `clone.ts`
/// (`git clone --recursive --progress -- <url> <path>`). Runs from the
/// destination's parent directory since the destination does not yet exist.
final class GitRepositoryCloneService: RepositoryCloneProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func clone(from url: String, to destinationURL: URL) async throws {
        let workingDirectory = destinationURL.deletingLastPathComponent()
        _ = try await client.run(
            ["clone", "--recursive", "--progress", "--", url, destinationURL.path],
            in: workingDirectory,
            timeout: 600
        )
    }
}
