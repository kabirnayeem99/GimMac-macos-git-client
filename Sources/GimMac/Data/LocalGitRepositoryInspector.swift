import Foundation

final class LocalGitRepositoryInspector: RepositoryInspecting {
    private let gitClient: GitClientProtocol

    init(gitClient: GitClientProtocol = ProcessGitClient()) {
        self.gitClient = gitClient
    }

    func inspectRepository(at url: URL) async throws -> RepositoryState {
        let branchResult = try await gitClient.run(["branch", "--show-current"], in: url, timeout: 10)
        let branch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        if !branch.isEmpty {
            return RepositoryState(currentBranch: branch, detachedHeadShortSHA: nil)
        }

        let headResult = try await gitClient.run(GitCommandBuilder.revParseHeadShort(), in: url, timeout: 10)
        let detached = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !detached.isEmpty else {
            throw GitAppError.invalidOutput(command: GitCommandBuilder.revParseHeadShort(), details: "Missing detached HEAD sha")
        }

        return RepositoryState(currentBranch: nil, detachedHeadShortSHA: detached)
    }
}
