import Foundation
import Observation

enum RepositoryPrimaryAction: Equatable {
    case fetch
    case commit
    case pull(Int)
    case push(Int)
    case sync(ahead: Int, behind: Int)
    case merge

    var label: String {
        switch self {
        case .fetch:
            return "Fetch origin"
        case .commit:
            return "Commit changes"
        case .pull:
            return "Pull origin"
        case .push:
            return "Push origin"
        case .sync:
            return "Sync branch"
        case .merge:
            return "Continue Merge"
        }
    }

    var badge: String? {
        switch self {
        case .pull(let count), .push(let count):
            return count > 0 ? String(count) : nil
        case .sync(let ahead, let behind):
            return "\(ahead)/\(behind)"
        case .fetch, .commit, .merge:
            return nil
        }
    }

    var subtitle: String {
        switch self {
        case .fetch:
            return "Repository is up to date"
        case .commit:
            return "You have local changes"
        case .pull(let count):
            return "Behind by \(count) commit\(count == 1 ? "" : "s")"
        case .push(let count):
            return "Ahead by \(count) commit\(count == 1 ? "" : "s")"
        case .sync(let ahead, let behind):
            return "Ahead \(ahead), behind \(behind)"
        case .merge:
            return "Resolve conflicts and commit"
        }
    }
}

struct GitUserProfile: Equatable {
    let name: String
    let email: String

    var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }

        if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2)).uppercased()
        }

        return "--"
    }
}

struct RepositoryScreenSnapshot: Equatable {
    let changedFiles: [ChangedFile]
    let commits: [Commit]
    let userProfile: GitUserProfile
    let primaryAction: RepositoryPrimaryAction
    let hasRemote: Bool
}

protocol RepositoryScreenDataProviding: Sendable {
    func loadSnapshot(for repository: Repository?) async -> RepositoryScreenSnapshot
}

final class LiveRepositoryScreenDataRepository: RepositoryScreenDataProviding, @unchecked Sendable {
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

    func loadSnapshot(for repository: Repository?) async -> RepositoryScreenSnapshot {
        guard let repository else {
            return .mock
        }

        do {
            async let changedFilesTask = statusProvider.fetchStatus(in: repository.url)
            async let commitsTask = historyProvider.fetchHistory(in: repository.url, maxCount: 50)
            async let userNameTask = readConfig("user.name", in: repository.url)
            async let userEmailTask = readConfig("user.email", in: repository.url)
            async let aheadBehindTask = readAheadBehind(in: repository.url)
            async let mergeInProgressTask = readMergeInProgress(in: repository.url)
            async let hasRemoteTask = readHasRemote(in: repository.url)

            let changedFiles = (try? await changedFilesTask) ?? []
            let commits = (try? await commitsTask) ?? []
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
        } catch {
            return .mock
        }
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
                ChangedFile(path: "Sources/GimMac/App/MainMenuFactory.swift", status: .modified, oldPath: nil),
                ChangedFile(path: "Sources/GimMac/Presentation/AppShell/MainSplitViewController.swift", status: .modified, oldPath: nil)
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

@MainActor
@Observable
final class RepositoryStoreViewModel {
    private let inspector: RepositoryInspecting
    private let screenRepository: RepositoryScreenDataProviding
    private let diffProvider: DiffProviding
    private let commitProvider: CommitProviding
    private let repositoryPersistence: RepositoryPersistenceProviding

    private(set) var selectedRepository: Repository?
    private(set) var repositoryState = RepositoryState(currentBranch: nil, detachedHeadShortSHA: nil)
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private(set) var primaryAction: RepositoryPrimaryAction = .fetch
    private(set) var hasRemote = false
    private(set) var changedFiles: [ChangedFile] = []
    private(set) var commits: [Commit] = []
    private(set) var currentGitUser = GitUserProfile(name: "Unknown User", email: "unknown@example.com")
    private(set) var checkedChangedFilePaths: Set<String> = []
    private(set) var selectedDiffDocument = DiffDocument.empty
    private(set) var isLoadingDiff = false
    private(set) var isCommitting = false
    private(set) var savedRepositories: [StoredRepository] = []

    var commitSummary = ""
    var commitDescription = ""
    var selectedHistoryCommitIndex = 0
    var selectedChangedFilePath: String?

    var changedFilesCount: Int {
        changedFiles.count
    }

    var selectedCommit: Commit? {
        guard !commits.isEmpty else {
            return nil
        }

        let safeIndex = min(max(selectedHistoryCommitIndex, 0), commits.count - 1)
        return commits[safeIndex]
    }

    var commitButtonLabel: String {
        "\(primaryAction.label)"
    }

    var lastCommitSectionTitle: String {
        selectedCommit == nil ? "No commits yet" : "Committed just now"
    }

    var lastCommitSummary: String {
        selectedCommit?.summary ?? "No recent commit"
    }

    init(
        inspector: RepositoryInspecting,
        screenRepository: RepositoryScreenDataProviding,
        diffProvider: DiffProviding,
        commitProvider: CommitProviding,
        repositoryPersistence: RepositoryPersistenceProviding
    ) {
        self.inspector = inspector
        self.screenRepository = screenRepository
        self.diffProvider = diffProvider
        self.commitProvider = commitProvider
        self.repositoryPersistence = repositoryPersistence
    }

    func selectRepository(at url: URL) async {
        isLoading = true
        errorMessage = nil
        selectedRepository = Repository(url: url)
        defer { isLoading = false }

        do {
            repositoryState = try await inspector.inspectRepository(at: url)
            _ = try await repositoryPersistence.saveOrUpdateRepository(path: url.path)
        } catch {
            repositoryState = RepositoryState(currentBranch: nil, detachedHeadShortSHA: nil)
            errorMessage = error.localizedDescription
        }

        await refreshRepositoryScreenData()
        await loadSavedRepositories()
    }

    func bootstrapRepositorySelectionOnLaunch() async {
        await loadSavedRepositories()

        do {
            if let selected = try await repositoryPersistence.selectMostRecentlyOpenedRepositoryOnLaunch(),
               selected.existsOnDisk {
                await selectRepository(at: selected.url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectPersistedRepository(id: UUID) async {
        do {
            guard let selected = try await repositoryPersistence.selectRepository(id: id) else {
                return
            }

            if !selected.existsOnDisk {
                await loadSavedRepositories()
                return
            }

            await selectRepository(at: selected.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSavedRepositories() async {
        do {
            savedRepositories = try await repositoryPersistence.getAllRepositoriesSortedByLastOpened()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRepositoryScreenData() async {
        let snapshot = await screenRepository.loadSnapshot(for: selectedRepository)
        primaryAction = snapshot.primaryAction
        hasRemote = snapshot.hasRemote
        changedFiles = snapshot.changedFiles
        commits = snapshot.commits
        currentGitUser = snapshot.userProfile

        let latestPaths = Set(changedFiles.map(\.path))
        let retainedChecks = checkedChangedFilePaths.intersection(latestPaths)
        let newPaths = latestPaths.subtracting(retainedChecks)
        checkedChangedFilePaths = retainedChecks.union(newPaths)

        if selectedChangedFilePath == nil {
            selectedChangedFilePath = changedFiles.first?.path
        }

        if commitSummary.isEmpty {
            commitSummary = selectedCommit?.summary ?? ""
        }

        if commitDescription.isEmpty {
            commitDescription = selectedCommit?.body ?? ""
        }

        await loadDiffForSelectedFile()
    }

    func selectHistoryCommit(at index: Int) {
        selectedHistoryCommitIndex = index
    }

    func selectChangedFile(path: String) {
        selectedChangedFilePath = path
        Task { [weak self] in
            await self?.loadDiffForSelectedFile()
        }
    }

    func isChangedFileChecked(path: String) -> Bool {
        checkedChangedFilePaths.contains(path)
    }

    func toggleChangedFileChecked(path: String) {
        if checkedChangedFilePaths.contains(path) {
            checkedChangedFilePaths.remove(path)
        } else {
            checkedChangedFilePaths.insert(path)
        }
    }

    var canCommitChanges: Bool {
        !isCommitting &&
        selectedRepository != nil &&
        !checkedChangedFilePaths.isEmpty &&
        !commitSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func commitChanges() async {
        guard canCommitChanges, let repository = selectedRepository else {
            return
        }

        let summary = commitSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = commitDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathsToCommit = checkedChangedFilePaths.sorted()

        isCommitting = true
        errorMessage = nil
        defer { isCommitting = false }

        do {
            try await commitProvider.commit(
                in: repository.url,
                paths: pathsToCommit,
                summary: summary,
                description: description.isEmpty ? nil : description
            )

            commitSummary = ""
            commitDescription = ""
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDiffForSelectedFile() async {
        guard let repository = selectedRepository, let path = selectedChangedFilePath else {
            selectedDiffDocument = .empty
            return
        }

        if let changedFile = changedFiles.first(where: { $0.path == path }),
           changedFile.status == .untracked {
            selectedDiffDocument = loadUntrackedFileDiff(repositoryURL: repository.url, path: path)
            return
        }

        isLoadingDiff = true
        defer { isLoadingDiff = false }

        do {
            selectedDiffDocument = try await diffProvider.fetchDiff(in: repository.url, for: path)
        } catch {
            selectedDiffDocument = DiffDocument(filePath: path, lines: [])
        }
    }

    private func loadUntrackedFileDiff(repositoryURL: URL, path: String) -> DiffDocument {
        let fileURL = repositoryURL.appendingPathComponent(path)
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return DiffDocument(filePath: path, lines: [])
        }

        let lines = content.components(separatedBy: .newlines)
        let diffLines = lines.enumerated().map { index, line in
            DiffDocumentLine(
                kind: .added,
                oldNumber: nil,
                newNumber: index + 1,
                text: line
            )
        }

        return DiffDocument(filePath: path, lines: diffLines)
    }
}
