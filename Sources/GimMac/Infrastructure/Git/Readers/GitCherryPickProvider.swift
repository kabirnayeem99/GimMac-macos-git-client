import Foundation

/// Applies existing commits on top of the current branch, preserving order and
/// cleaning up on conflict.
final class GitCherryPickProvider: CherryPickProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func cherryPick(commits: [Commit], in repositoryURL: URL) async throws {
        guard !commits.isEmpty else { return }

        // commits is newest-first; cherry-pick applies arguments left→right, so
        // reverse to oldest-first to preserve original commit order on HEAD.
        let shas = commits.reversed().map(\.id)
        do {
            _ = try await client.run(["cherry-pick"] + shas, in: repositoryURL, timeout: 120)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Conflict or failure leaves the repo mid-cherry-pick. Abort so the
            // working tree returns to a clean state, then surface the error.
            _ = try? await client.run(["cherry-pick", "--abort"], in: repositoryURL, timeout: 15)
            throw error
        }
    }

    func continueCherryPick(in repositoryURL: URL) async throws -> RebaseOutcome {
        do {
            // Force a no-op editor so the prepared commit message is accepted
            // non-interactively (matches `continueRebase`).
            _ = try await client.run(
                ["-c", "core.editor=true", "cherry-pick", "--continue"],
                in: repositoryURL, timeout: 120
            )
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

    func abortCherryPick(in repositoryURL: URL) async throws {
        _ = try await client.run(["cherry-pick", "--abort"], in: repositoryURL, timeout: 15)
    }
}
