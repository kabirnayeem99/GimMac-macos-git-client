import Foundation

final class LiveRepositoryScreenDataRepository: RepositoryScreenDataProviding, Sendable {
    private let statusProvider: StatusProviding
    private let historyProvider: HistoryProviding
    private let upstreamProvider: BranchUpstreamProviding
    private let gitClient: GitClientProtocol

    init(
        statusProvider: StatusProviding,
        historyProvider: HistoryProviding,
        upstreamProvider: BranchUpstreamProviding,
        gitClient: GitClientProtocol
    ) {
        self.statusProvider = statusProvider
        self.historyProvider = historyProvider
        self.upstreamProvider = upstreamProvider
        self.gitClient = gitClient
    }

    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot {
        guard let repository else {
            return .mock
        }

        async let changedFilesTask = statusProvider.fetchStatus(in: repository.url)
        async let commitsTask = historyProvider.fetchHistory(in: repository.url, maxCount: 50)
        async let userNameTask = readConfig("user.name", in: repository.url)
        async let userEmailTask = readConfig("user.email", in: repository.url)
        async let aheadBehindTask = readAheadBehind(in: repository.url)
        async let conflictStateTask = readConflictState(in: repository.url)
        async let remoteNameTask = readRemoteName(in: repository.url)

        let changedFiles = try await changedFilesTask
        let commits = try await commitsTask
        let userName = (try? await userNameTask)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userEmail = (try? await userEmailTask)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let aheadBehind = (try? await aheadBehindTask) ?? (0, 0)
        let conflictState = (try? await conflictStateTask) ?? .none
        let remoteName = try? await remoteNameTask

        let upstream = await resolveUpstream(for: repository.url, remoteName: remoteName)
        let unpushedSHAs = await readUnpushedSHAs(in: repository.url, upstream: upstream, remoteName: remoteName)

        let forcePushNeeded: Bool
        if aheadBehind.0 > 0 && aheadBehind.1 > 0, let remote = remoteName {
            forcePushNeeded = await readForcePushNeeded(remoteName: remote, in: repository.url)
        } else {
            forcePushNeeded = false
        }

        let user = GitUserProfile(
            name: userName?.isEmpty == false ? userName! : (commits.first?.authorName ?? "Unknown User"),
            email: userEmail?.isEmpty == false ? userEmail! : (commits.first?.authorEmail ?? "unknown@example.com")
        )

        let primaryAction = derivePrimaryAction(
            changedFilesCount: changedFiles.count,
            ahead: aheadBehind.0,
            behind: aheadBehind.1,
            conflictState: conflictState,
            remoteName: remoteName,
            upstream: upstream,
            forcePushNeeded: forcePushNeeded
        )

        return RepositoryScreenSnapshot(
            changedFiles: changedFiles,
            commits: commits,
            userProfile: user,
            primaryAction: primaryAction,
            remoteName: remoteName,
            forcePushNeeded: forcePushNeeded,
            unpushedSHAs: unpushedSHAs
        )
    }

    private func resolveUpstream(for repositoryURL: URL, remoteName: String?) async -> String? {
        guard remoteName != nil else { return nil }
        let inspector = LocalGitRepositoryInspector(gitClient: gitClient)
        guard let tipState = try? await inspector.inspectRepository(at: repositoryURL),
              case .valid(let branch) = tipState else { return nil }
        return try? await upstreamProvider.fetchUpstream(for: branch.name, in: repositoryURL)
    }

    private func readConfig(_ key: String, in repositoryURL: URL) async throws -> String {
        let result = try await gitClient.run(["config", key], in: repositoryURL, timeout: 5)
        return result.stdout
    }

    private func readAheadBehind(in repositoryURL: URL) async throws -> (Int, Int) {
        let result = try await gitClient.run(
            ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
            in: repositoryURL,
            timeout: 5
        )
        let pieces = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard pieces.count == 2, let behind = Int(pieces[0]), let ahead = Int(pieces[1]) else {
            return (0, 0)
        }
        return (ahead, behind)
    }

    private func readConflictState(in repositoryURL: URL) async throws -> ConflictState {
        let merge = (try? await gitClient.run(
            ["rev-parse", "-q", "--verify", "MERGE_HEAD"], in: repositoryURL, timeout: 5
        )) != nil
        let rebase = (try? await gitClient.run(
            ["rev-parse", "-q", "--verify", "REBASE_HEAD"], in: repositoryURL, timeout: 5
        )) != nil
        let cherryPick = (try? await gitClient.run(
            ["rev-parse", "-q", "--verify", "CHERRY_PICK_HEAD"], in: repositoryURL, timeout: 5
        )) != nil
        if merge { return .merge }
        if rebase { return .rebase }
        if cherryPick { return .cherryPick }
        return .none
    }

    private func readRemoteName(in repositoryURL: URL) async throws -> String? {
        let result = try await gitClient.run(["remote", "-v"], in: repositoryURL, timeout: 5)
        let line = result.stdout.components(separatedBy: "\n").first(where: { !$0.isEmpty })
        return line?.components(separatedBy: "\t").first
    }

    private func readForcePushNeeded(remoteName: String, in url: URL) async -> Bool {
        let result = try? await gitClient.run(
            ["merge-base", "--is-ancestor", remoteName, "HEAD"],
            in: url,
            timeout: 5
        )
        return result?.exitCode == 1
    }

    private func readUnpushedSHAs(in repositoryURL: URL, upstream: String?, remoteName: String?) async -> Set<String> {
        guard remoteName != nil else { return [] }
        let args: [String]
        if let upstream {
            args = ["log", "\(upstream)..HEAD", "--format=%H"]
        } else {
            args = ["log", "HEAD", "--not", "--remotes", "--format=%H"]
        }
        guard let result = try? await gitClient.run(args, in: repositoryURL, timeout: 5) else { return [] }
        return Set(result.stdout.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty })
    }

    private func derivePrimaryAction(
        changedFilesCount: Int,
        ahead: Int,
        behind: Int,
        conflictState: ConflictState,
        remoteName: String?,
        upstream: String?,
        forcePushNeeded: Bool
    ) -> RepositoryPrimaryAction {
        switch conflictState {
        case .merge:      return .merge
        case .rebase:     return .rebase
        case .cherryPick: return .cherryPick
        case .none:       break
        }

        guard let remote = remoteName else {
            return .publishRepository
        }

        guard upstream != nil else {
            return .publishBranch(remote: remote)
        }

        if forcePushNeeded {
            return .forcePush(remote: remote, ahead: ahead)
        }

        if ahead > 0 && behind > 0 {
            return .sync(remote: remote, ahead: ahead, behind: behind)
        }

        if ahead > 0 {
            return .push(remote: remote, ahead: ahead)
        }

        if behind > 0 {
            return .pull(remote: remote, behind: behind)
        }

        return .fetch(remote: remote)
    }
}

private extension RepositoryScreenSnapshot {
    static var mock: RepositoryScreenSnapshot {
        let now = Date()

        return RepositoryScreenSnapshot(
            changedFiles: [
                ChangedFile(path: "Sources/GimMac/App/MainMenuFactory.swift", status: .modified, oldPath: nil, isStaged: false, hasConflict: false),
                ChangedFile(path: "Sources/GimMac/Presentation/AppShell/MainSplitViewController.swift", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)
            ],
            commits: [
                Commit(
                    id: "18ac194aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    shortHash: "18ac194",
                    authorName: "Naimul Kabir",
                    authorEmail: "naimul@example.com",
                    date: now.addingTimeInterval(-600),
                    summary: "Update MainSplitViewController.swift",
                    body: "Restructure main screen and split views"
                )
            ],
            userProfile: GitUserProfile(name: "Naimul Kabir", email: "naimul@example.com"),
            primaryAction: .push(remote: "origin", ahead: 1),
            remoteName: nil,
            forcePushNeeded: false,
            unpushedSHAs: ["18ac194aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
        )
    }
}
