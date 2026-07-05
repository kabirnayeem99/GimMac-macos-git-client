import Foundation

/// Implements `BranchOperating`. All commands pass arguments as arrays —
/// never shell strings — per `AGENTS.md` security rules.
final class GitBranchOperator: BranchOperating, DefaultBranchRenaming, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    @discardableResult
    func createBranch(
        named name: String,
        from startPoint: BranchStartPoint,
        noTrack: Bool,
        in repositoryURL: URL
    ) async throws -> String {
        var arguments = ["branch"]
        if noTrack {
            arguments.append("--no-track")
        }
        arguments.append("--")
        arguments.append(name)
        if let startPointArg = try await Self.startPointRevspec(startPoint, client: client, repositoryURL: repositoryURL) {
            arguments.append(startPointArg)
        }
        _ = try await client.run(arguments, in: repositoryURL, timeout: 10)
        return name
    }

    func switchBranch(to branch: Branch, in repositoryURL: URL) async throws {
        // Prefer `git switch` over `git checkout` for branch switching — per
        // implementation plan §Phase 3.2.
        let targetName: String
        if branch.isLocal {
            targetName = branch.name
        } else {
            // For remote branches, switching creates a local tracking branch.
            targetName = branch.nameWithoutRemote
        }
        _ = try await client.run(["switch", "--", targetName], in: repositoryURL, timeout: 15)
    }

    func deleteLocalBranch(_ branch: Branch, force: Bool, in repositoryURL: URL) async throws {
        let flag = force ? "-D" : "-d"
        _ = try await client.run(["branch", flag, "--", branch.name], in: repositoryURL, timeout: 10)
    }

    func deleteRemoteBranch(_ branch: Branch, remote: String, in repositoryURL: URL) async throws {
        // Pass empty refspec as a single argument: ":branchName".
        let refspec = ":\(branch.nameWithoutRemote)"
        do {
            _ = try await client.run(["push", remote, refspec], in: repositoryURL, timeout: 60)
        } catch let error as GitAppError {
            // The remote ref may already have been deleted. Git reports this as
            // "remote ref does not exist". Mirror GitHub Desktop and treat it as
            // an idempotent success, pruning our local remote-tracking ref to
            // reflect the state the push would have produced. Any other failure
            // (auth, network, protected branch) still propagates.
            guard case let .commandFailed(_, _, _, stderr) = error,
                  stderr.lowercased().contains("remote ref does not exist") else {
                throw error
            }
            let trackingRef = "refs/remotes/\(remote)/\(branch.nameWithoutRemote)"
            _ = try? await client.run(["update-ref", "-d", trackingRef], in: repositoryURL, timeout: 10)
        }
    }

    @discardableResult
    func renameBranch(
        _ branch: Branch,
        to newName: String,
        force: Bool,
        in repositoryURL: URL
    ) async throws -> String {
        let flag = force ? "-M" : "-m"
        _ = try await client.run(["branch", flag, "--", branch.name, newName], in: repositoryURL, timeout: 10)
        return newName
    }

    // MARK: - DefaultBranchRenaming

    func renameCurrentBranch(from oldName: String, to newName: String, in repositoryURL: URL) async throws {
        _ = try await client.run(["branch", "-M", "--", oldName, newName], in: repositoryURL, timeout: 10)
    }

    // MARK: - Start point translation

    /// Translates a `BranchStartPoint` into a single revspec argument or `nil`
    /// when the start point is implicit (current branch / HEAD).
    private static func startPointRevspec(
        _ startPoint: BranchStartPoint,
        client: GitClientProtocol,
        repositoryURL: URL
    ) async throws -> String? {
        switch startPoint {
        case .currentBranch:
            return nil
        case .head:
            return "HEAD"
        case .branch(let branch):
            return branch.name
        case .commit(let sha):
            return sha
        case .defaultBranch:
            // Try origin/HEAD first; fall back to the configured init.defaultBranch.
            if let resolved = try? await client.run(
                ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
                in: repositoryURL,
                timeout: 5
            ) {
                let value = resolved.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            if let configured = try? await client.run(
                ["config", "--get", "init.defaultBranch"],
                in: repositoryURL,
                timeout: 5
            ) {
                let value = configured.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            return "HEAD"
        }
    }
}
