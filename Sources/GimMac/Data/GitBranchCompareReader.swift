import Foundation

/// Implements `BranchCompareProviding` using `git rev-list` + `git log`.
final class GitBranchCompareReader: BranchCompareProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func compareBranches(
        base: Branch,
        compare: Branch,
        in repositoryURL: URL
    ) async throws -> BranchCompareResult {
        // Ahead/behind: `<behind>\t<ahead>` per the `--left-right --count` doc
        // when invoked as `git rev-list --left-right --count base...compare`.
        let countResult = try await client.run(
            ["rev-list", "--left-right", "--count", "\(base.name)...\(compare.name)"],
            in: repositoryURL,
            timeout: 15
        )
        let trimmed = countResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(whereSeparator: { $0 == "\t" || $0 == " " })
        guard parts.count >= 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            throw GitAppError.invalidOutput(
                command: ["rev-list", "--left-right", "--count", "\(base.name)...\(compare.name)"],
                details: "Could not parse ahead/behind output: \(trimmed)"
            )
        }

        // Commits in `compare` not in `base`.
        let logResult = try await client.run(
            ["log", "--format=\(GitLogParser.logFormat)", "--no-merges", "\(base.name)..\(compare.name)"],
            in: repositoryURL,
            timeout: 20
        )
        let commits = GitLogParser.parse(logResult.stdout)

        return BranchCompareResult(
            base: base,
            compare: compare,
            aheadBehind: AheadBehind(ahead: ahead, behind: behind),
            commits: commits
        )
    }
}
