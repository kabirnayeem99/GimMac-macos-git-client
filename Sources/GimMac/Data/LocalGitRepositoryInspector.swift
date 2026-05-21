import Foundation

final class LocalGitRepositoryInspector: RepositoryInspecting {
    private let gitClient: GitClientProtocol

    init(gitClient: GitClientProtocol) {
        self.gitClient = gitClient
    }

    func inspectRepository(at url: URL) async throws -> TipState {
        let typeResult = try? await gitClient.run(
            ["rev-parse", "--is-bare-repository", "--show-cdup", "--git-dir"],
            in: url, timeout: 5
        )
        if let typeResult {
            if typeResult.exitCode == 128 && typeResult.stderr.contains("dubious ownership") {
                throw GitAppError.unsafeRepository(path: url.path)
            }
            if typeResult.stdout.hasPrefix("true\n") {
                throw GitAppError.bareRepository
            }
            if typeResult.exitCode != 0 || typeResult.stdout.isEmpty {
                throw GitAppError.notARepository
            }
        }

        let branchResult = try? await gitClient.run(["branch", "--show-current"], in: url, timeout: 10)
        let branch = branchResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let headResult = try? await gitClient.run(["rev-parse", "HEAD"], in: url, timeout: 10)
        let headHash = headResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

        if !branch.isEmpty, let sha = headHash {
            return .valid(branch: BranchSummary(name: branch, upstream: nil, sha: sha))
        }

        if !branch.isEmpty, headHash == nil {
            return .unborn(ref: branch)
        }

        if branch.isEmpty, let sha = headHash {
            return .detached(sha: String(sha.prefix(7)))
        }

        if let symRef = try? await gitClient.run(["symbolic-ref", "HEAD"], in: url, timeout: 5) {
            let ref = symRef.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if ref.hasPrefix("refs/heads/") {
                return .unborn(ref: String(ref.dropFirst("refs/heads/".count)))
            }
        }

        throw GitAppError.invalidOutput(command: ["branch", "--show-current"], details: "Cannot determine HEAD state")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
