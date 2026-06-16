import Foundation

/// Rebase the current branch onto a base, with the continue/skip/abort state
/// machine. Mirrors GitHub Desktop's `rebase.ts`.
final class GitRebaseService: RebaseProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func rebase(base: String, target: String, in repositoryURL: URL) async throws -> RebaseOutcome {
        try await runRebase(["rebase", base, target], in: repositoryURL)
    }

    func continueRebase(in repositoryURL: URL) async throws -> RebaseOutcome {
        // `rebase --continue` re-commits the resolved step and would otherwise
        // launch an interactive editor for the message. Force a no-op editor so
        // the prepared commit message is accepted non-interactively.
        try await runRebase(
            ["-c", "core.editor=true", "rebase", "--continue"], in: repositoryURL, timeout: 120
        )
    }

    func skipCommit(in repositoryURL: URL) async throws -> RebaseOutcome {
        try await runRebase(["rebase", "--skip"], in: repositoryURL, timeout: 120)
    }

    func abortRebase(in repositoryURL: URL) async throws {
        _ = try await client.run(["rebase", "--abort"], in: repositoryURL, timeout: 30)
    }

    /// Runs a rebase step. A step that stops on conflicts exits non-zero with
    /// "CONFLICT" / "could not apply" across stdout or stderr.
    private func runRebase(
        _ args: [String],
        in repositoryURL: URL,
        timeout: TimeInterval = 120
    ) async throws -> RebaseOutcome {
        do {
            _ = try await client.run(args, in: repositoryURL, timeout: timeout)
            return .completed
        } catch let error as GitAppError {
            if case let .commandFailed(_, _, stdout, stderr) = error {
                let output = stdout + "\n" + stderr
                if output.localizedCaseInsensitiveContains("conflict")
                    || output.localizedCaseInsensitiveContains("could not apply") {
                    return .conflicts
                }
            }
            throw error
        }
    }
}
