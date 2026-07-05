import Foundation

/// Generic branch merge. Mirrors GitHub Desktop's `merge.ts`:
/// `git merge [--no-verify] <branch>` and the squash variant
/// `git merge --squash <branch>` followed by `git commit --no-edit`.
final class GitMergeService: MergeBranchProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func merge(branch: String, noVerify: Bool, in repositoryURL: URL) async throws -> MergeOutcome {
        var args = ["merge"]
        if noVerify { args.append("--no-verify") }
        args.append("--")
        args.append(branch)
        return try await runMerge(args, in: repositoryURL)
    }

    func squashMerge(branch: String, noVerify: Bool, in repositoryURL: URL) async throws -> MergeOutcome {
        var args = ["merge", "--squash"]
        if noVerify { args.append("--no-verify") }
        args.append("--")
        args.append(branch)

        let outcome = try await runMerge(args, in: repositoryURL)
        guard outcome == .success else { return outcome }

        // `--squash` stages the changes but does not commit. Finalize with the
        // auto-generated SQUASH_MSG (GitHub Desktop uses `commit --no-edit`).
        var commitArgs = ["commit", "--no-edit"]
        if noVerify { commitArgs.append("--no-verify") }
        _ = try await client.run(commitArgs, in: repositoryURL, timeout: 30)
        return .success
    }

    func abortMerge(in repositoryURL: URL) async throws {
        _ = try await client.run(["merge", "--abort"], in: repositoryURL, timeout: 30)
    }

    func createMergeCommit(in repositoryURL: URL) async throws {
        // Finalize a conflict-resolved merge. Like GitHub Desktop, a plain
        // `git commit --no-edit` records the merge using the prepared MERGE_MSG
        // rather than `git merge --continue`.
        _ = try await client.run(["commit", "--no-edit"], in: repositoryURL, timeout: 30)
    }

    /// Runs a merge, translating git's exit-code semantics into `MergeOutcome`.
    /// A conflicted merge exits non-zero with "CONFLICT" on stdout; an
    /// up-to-date merge succeeds with "Already up to date".
    private func runMerge(_ args: [String], in repositoryURL: URL) async throws -> MergeOutcome {
        do {
            let result = try await client.run(args, in: repositoryURL, timeout: 60)
            if result.stdout.localizedCaseInsensitiveContains("already up to date") {
                return .alreadyUpToDate
            }
            return .success
        } catch let error as GitAppError {
            if case let .commandFailed(_, _, stdout, _) = error,
               stdout.localizedCaseInsensitiveContains("conflict") {
                return .conflicts
            }
            throw error
        }
    }
}
