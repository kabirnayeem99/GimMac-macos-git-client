import Foundation

/// Reverts an arbitrary commit, aborting the operation on conflict so the
/// working tree is left in a clean state.
final class GitRevertProvider: RevertProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func revert(commit: Commit, in repositoryURL: URL) async throws {
        do {
            _ = try await client.run(["revert", "--no-edit", commit.id], in: repositoryURL, timeout: 60)
        } catch {
            // Conflict or failure leaves the repo mid-revert. Abort so the
            // working tree returns to a clean state, then surface the error.
            _ = try? await client.run(["revert", "--abort"], in: repositoryURL, timeout: 15)
            throw error
        }
    }
}
