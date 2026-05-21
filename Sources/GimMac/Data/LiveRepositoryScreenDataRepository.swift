import Foundation

final class LiveRepositoryScreenDataRepository: RepositoryScreenDataProviding, Sendable {
    private let statusProvider: StatusProviding
    private let historyProvider: HistoryProviding
    private let gitClient: GitClientProtocol

    init(
        statusProvider: StatusProviding,
        historyProvider: HistoryProviding,
        gitClient: GitClientProtocol
    ) {
        self.statusProvider = statusProvider
        self.historyProvider = historyProvider
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
        async let mergeInProgressTask = readMergeInProgress(in: repository.url)
        async let hasRemoteTask = readHasRemote(in: repository.url)

        let changedFiles = try await changedFilesTask
        let commits = try await commitsTask
        let userName = (try? await userNameTask)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userEmail = (try? await userEmailTask)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let aheadBehind = (try? await aheadBehindTask) ?? (0, 0)
        let mergeInProgress = (try? await mergeInProgressTask) ?? false
        let hasRemote = (try? await hasRemoteTask) ?? false

        let user = GitUserProfile(
            name: userName?.isEmpty == false ? userName! : (commits.first?.authorName ?? "Unknown User"),
            email: userEmail?.isEmpty == false ? userEmail! : (commits.first?.authorEmail ?? "unknown@example.com")
        )

        let primaryAction = derivePrimaryAction(
            changedFilesCount: changedFiles.count,
            ahead: aheadBehind.0,
            behind: aheadBehind.1,
            mergeInProgress: mergeInProgress
        )

        return RepositoryScreenSnapshot(
            changedFiles: changedFiles,
            commits: commits,
            userProfile: user,
            primaryAction: primaryAction,
            hasRemote: hasRemote
        )
    }

    private func readConfig(_ key: String, in repositoryURL: URL) async throws -> String {
        let result = try await gitClient.run(["config", key], in: repositoryURL, timeout: 5)
        return result.stdout
    }

    private func readAheadBehind(in repositoryURL: URL) async throws -> (Int, Int) {
        let result = try await gitClient.run(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], in: repositoryURL, timeout: 5)
        let pieces = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard pieces.count == 2, let behind = Int(pieces[0]), let ahead = Int(pieces[1]) else {
            return (0, 0)
        }

        return (ahead, behind)
    }

    private func readMergeInProgress(in repositoryURL: URL) async throws -> Bool {
        do {
            _ = try await gitClient.run(["rev-parse", "-q", "--verify", "MERGE_HEAD"], in: repositoryURL, timeout: 5)
            return true
        } catch {
            return false
        }
    }

    private func readHasRemote(in repositoryURL: URL) async throws -> Bool {
        let result = try await gitClient.run(["remote", "get-url", "origin"], in: repositoryURL, timeout: 5)
        return !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func derivePrimaryAction(
        changedFilesCount: Int,
        ahead: Int,
        behind: Int,
        mergeInProgress: Bool
    ) -> RepositoryPrimaryAction {
        if mergeInProgress {
            return .merge
        }

        if ahead > 0 && behind > 0 {
            return .sync(ahead: ahead, behind: behind)
        }

        if ahead > 0 {
            return .push(ahead)
        }

        if behind > 0 {
            return .pull(behind)
        }

        if changedFilesCount > 0 {
            return .commit
        }

        return .fetch
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
            primaryAction: .push(1),
            hasRemote: false
        )
    }
}
