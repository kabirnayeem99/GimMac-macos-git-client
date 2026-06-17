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
}

extension LiveRepositoryScreenDataRepository {
    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot {
        let critical = try await loadCriticalSnapshot(for: repository, inspection: nil)
        guard let repository else {
            return .mock
        }
        let secondary = try await loadSecondarySnapshot(for: repository, inspection: nil, criticalSnapshot: critical)
        return RepositoryScreenSnapshot(
            changedFiles: critical.changedFiles,
            commits: critical.commits,
            userProfile: secondary.userProfile,
            primaryAction: secondary.primaryAction,
            remoteName: secondary.remoteName,
            forcePushNeeded: secondary.forcePushNeeded,
            unpushedSHAs: secondary.unpushedSHAs
        )
    }

    func loadCriticalSnapshot(
        for repository: Repository?,
        inspection: RepositoryInspectionResult?
    ) async throws -> CriticalRepositorySnapshot {
        guard let repository else {
            return RepositoryScreenSnapshot.mock.criticalSnapshot
        }

        async let changedFilesTask = statusProvider.fetchStatus(in: repository.url)
        async let commitsTask = historyProvider.fetchHistory(in: repository.url, maxCount: HistoryPaging.pageSize, skip: 0)
        async let conflictStateTask = readConflictState(in: repository.url, inspection: inspection)

        let changedFiles = try await changedFilesTask
        let commits = try await commitsTask
        let conflictState = (try? await conflictStateTask) ?? .none

        let user = GitUserProfile(
            name: commits.first?.authorName ?? "Unknown User",
            email: commits.first?.authorEmail ?? "unknown@example.com"
        )

        let primaryAction: RepositoryPrimaryAction
        switch conflictState {
        case .merge:
            primaryAction = .merge
        case .rebase:
            primaryAction = .rebase
        case .cherryPick:
            primaryAction = .cherryPick
        case .none:
            primaryAction = changedFiles.isEmpty ? .publishRepository : .commit
        }

        return CriticalRepositorySnapshot(
            changedFiles: changedFiles,
            commits: commits,
            userProfile: user,
            primaryAction: primaryAction,
            remoteName: nil,
            forcePushNeeded: false,
            unpushedSHAs: []
        )
    }

    func loadSecondarySnapshot(
        for repository: Repository,
        inspection: RepositoryInspectionResult?,
        criticalSnapshot: CriticalRepositorySnapshot
    ) async throws -> SecondaryRepositorySnapshot {
        async let identityTask = readUserIdentity(in: repository.url)
        async let aheadBehindTask = readAheadBehind(in: repository.url)
        async let remoteNameTask = readRemoteName(in: repository.url)

        let identity = try? await identityTask
        let aheadBehind = (try? await aheadBehindTask) ?? (0, 0)
        let remoteName = try? await remoteNameTask
        let upstream = await resolveUpstream(for: repository.url, remoteName: remoteName, inspection: inspection)
        let unpushedSHAs = await readUnpushedSHAs(in: repository.url, upstream: upstream, remoteName: remoteName)

        let forcePushNeeded: Bool
        if aheadBehind.0 > 0 && aheadBehind.1 > 0, remoteName != nil, let upstream {
            forcePushNeeded = await readForcePushNeeded(upstream: upstream, in: repository.url)
        } else {
            forcePushNeeded = false
        }
        let user = GitUserProfile(
            name: identity?.name ?? criticalSnapshot.userProfile.name,
            email: identity?.email ?? criticalSnapshot.userProfile.email
        )

        let primaryAction = derivePrimaryAction(
            inputs: .init(
                changedFilesCount: criticalSnapshot.changedFiles.count,
                ahead: aheadBehind.0,
                behind: aheadBehind.1,
                conflictState: conflictState(from: criticalSnapshot.primaryAction),
                remoteName: remoteName,
                upstream: upstream,
                forcePushNeeded: forcePushNeeded
            )
        )

        return SecondaryRepositorySnapshot(
            userProfile: user,
            primaryAction: primaryAction,
            remoteName: remoteName,
            forcePushNeeded: forcePushNeeded,
            unpushedSHAs: unpushedSHAs
        )
    }

    func loadMoreCommits(for repository: Repository, skip: Int, maxCount: Int) async throws -> [Commit] {
        try await historyProvider.fetchHistory(in: repository.url, maxCount: maxCount, skip: skip)
    }
}

private extension LiveRepositoryScreenDataRepository {
    private func resolveUpstream(
        for repositoryURL: URL,
        remoteName: String?,
        inspection: RepositoryInspectionResult?
    ) async -> String? {
        guard remoteName != nil else { return nil }
        let branchName: String?
        if let inspectedBranchName = inspection?.branchName {
            branchName = inspectedBranchName
        } else {
            branchName = await readCurrentBranchName(in: repositoryURL)
        }

        guard let branchName, !branchName.isEmpty else { return nil }
        return try? await upstreamProvider.fetchUpstream(for: branchName, in: repositoryURL)
    }

    private func readCurrentBranchName(in repositoryURL: URL) async -> String? {
        guard let result = try? await gitClient.run(
            ["status", "--porcelain=v2", "--branch", "--untracked-files=no"],
            in: repositoryURL,
            priority: .background,
            timeout: 5
        ) else {
            return nil
        }

        for line in result.stdout.split(whereSeparator: \.isNewline) {
            guard line.hasPrefix("# branch.head ") else { continue }
            let branchName = String(line.dropFirst("# branch.head ".count))
            return branchName == "(detached)" ? nil : branchName
        }
        return nil
    }

    private struct GitUserIdentity {
        let name: String?
        let email: String?
    }

    private func readUserIdentity(in repositoryURL: URL) async throws -> GitUserIdentity {
        let result = try await gitClient.run(
            ["config", "--null", "--get-regexp", "^user\\.(name|email)$"],
            in: repositoryURL,
            priority: .background,
            timeout: 5
        )
        var name: String?
        var email: String?
        for record in result.stdout.split(separator: "\u{0}") {
            let pieces = record.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard pieces.count == 2 else { continue }
            switch pieces[0] {
            case "user.name":
                name = String(pieces[1])
            case "user.email":
                email = String(pieces[1])
            default:
                break
            }
        }
        return GitUserIdentity(
            name: name?.isEmpty == false ? name : nil,
            email: email?.isEmpty == false ? email : nil
        )
    }

    private func readAheadBehind(in repositoryURL: URL) async throws -> (Int, Int) {
        let result = try await gitClient.run(
            ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
            in: repositoryURL,
            priority: .background,
            timeout: 5
        )
        let pieces = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard pieces.count == 2, let behind = Int(pieces[0]), let ahead = Int(pieces[1]) else {
            return (0, 0)
        }
        return (ahead, behind)
    }

    private func readConflictState(
        in repositoryURL: URL,
        inspection: RepositoryInspectionResult?
    ) async throws -> ConflictState {
        // Resolve the git dir once, then probe the in-progress sentinel files
        // directly. This replaces three separate `rev-parse` subprocesses with a
        // single one plus cheap filesystem checks.
        let resolvedGitDir: String?
        if let gitDir = inspection?.gitDir, !gitDir.isEmpty {
            resolvedGitDir = gitDir
        } else {
            resolvedGitDir = try? await gitClient.run(
                ["rev-parse", "--git-dir"],
                in: repositoryURL,
                priority: .userInteractive,
                timeout: 5
            ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let gitDir = resolvedGitDir, !gitDir.isEmpty else {
            return .none
        }

        let base = URL(fileURLWithPath: gitDir, isDirectory: true, relativeTo: repositoryURL)
        let fileManager = FileManager.default
        func exists(_ name: String) -> Bool {
            fileManager.fileExists(atPath: base.appendingPathComponent(name).path)
        }

        if exists("MERGE_HEAD") { return .merge }
        if exists("REBASE_HEAD") { return .rebase }
        if exists("CHERRY_PICK_HEAD") { return .cherryPick }
        return .none
    }

    private func conflictState(from primaryAction: RepositoryPrimaryAction) -> ConflictState {
        switch primaryAction {
        case .merge:
            return .merge
        case .rebase:
            return .rebase
        case .cherryPick:
            return .cherryPick
        default:
            return .none
        }
    }

    private func readRemoteName(in repositoryURL: URL) async throws -> String? {
        let result = try await gitClient.run(["remote", "-v"], in: repositoryURL, priority: .background, timeout: 5)
        let line = result.stdout.components(separatedBy: "\n").first(where: { !$0.isEmpty })
        return line?.components(separatedBy: "\t").first
    }

    /// A force push is needed when the upstream tip is **not** an ancestor of
    /// HEAD (history was rewritten). `merge-base --is-ancestor` exits 0 when it
    /// is an ancestor and 1 when it is not; any other exit is an error. The bare
    /// remote name is not a commit, so the resolved upstream ref must be passed.
    private func readForcePushNeeded(upstream: String, in url: URL) async -> Bool {
        do {
            _ = try await gitClient.run(
                ["merge-base", "--is-ancestor", upstream, "HEAD"],
                in: url,
                priority: .background,
                timeout: 5
            )
            return false
        } catch let GitAppError.commandFailed(_, exitCode, _, _) where exitCode == 1 {
            return true
        } catch {
            return false
        }
    }

    private func readUnpushedSHAs(in repositoryURL: URL, upstream: String?, remoteName: String?) async -> Set<String> {
        guard remoteName != nil else { return [] }
        let args: [String]
        if let upstream {
            args = ["log", "\(upstream)..HEAD", "--format=%H"]
        } else {
            args = ["log", "HEAD", "--not", "--remotes", "--format=%H"]
        }
        guard let result = try? await gitClient.run(args, in: repositoryURL, priority: .background, timeout: 5) else { return [] }
        return Set(result.stdout.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty })
    }

    private struct PrimaryActionInputs {
        let changedFilesCount: Int
        let ahead: Int
        let behind: Int
        let conflictState: ConflictState
        let remoteName: String?
        let upstream: String?
        let forcePushNeeded: Bool
    }

    private func derivePrimaryAction(inputs: PrimaryActionInputs) -> RepositoryPrimaryAction {
        let ahead = inputs.ahead
        let behind = inputs.behind
        let conflictState = inputs.conflictState
        let remoteName = inputs.remoteName
        let upstream = inputs.upstream
        let forcePushNeeded = inputs.forcePushNeeded
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
                ChangedFile(path: "Sources/GimMac/Presentation/Shell/SplitViews/MainSplitViewController.swift", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)
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
