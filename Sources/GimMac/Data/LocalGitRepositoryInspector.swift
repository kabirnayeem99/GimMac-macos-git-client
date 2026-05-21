import Foundation

final class LocalGitRepositoryInspector: RepositoryInspecting {
    private let gitClient: GitClientProtocol

    init(gitClient: GitClientProtocol) {
        self.gitClient = gitClient
    }

    func inspectRepository(at url: URL) async throws -> RepositoryState {
        async let branchTask = gitClient.run(["branch", "--show-current"], in: url, timeout: 10)
        async let headTask   = gitClient.run(["rev-parse", "HEAD"],        in: url, timeout: 10)

        let branch   = try await branchTask.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let headHash = (try? await headTask)?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        if !branch.isEmpty {
            return RepositoryState(currentBranch: branch, detachedHeadShortSHA: nil, headHash: headHash)
        }

        let shortSHA = headHash.map { String($0.prefix(7)) } ?? ""
        guard !shortSHA.isEmpty else {
            throw GitAppError.invalidOutput(command: ["rev-parse", "HEAD"], details: "Missing detached HEAD sha")
        }

        return RepositoryState(currentBranch: nil, detachedHeadShortSHA: shortSHA, headHash: headHash)
    }
}
