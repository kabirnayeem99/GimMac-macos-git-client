import Foundation
import XCTest
@testable import GimMac

private struct MockRepositoryInspector: RepositoryInspecting, Sendable {
    let result: Result<RepositoryInspectionResult, Error>

    func inspectRepository(at url: URL) async throws -> RepositoryInspectionResult {
        try result.get()
    }
}

private actor SequencedRepositoryInspector: RepositoryInspecting {
    var results: [Result<RepositoryInspectionResult, Error>]

    init(results: [Result<RepositoryInspectionResult, Error>]) {
        self.results = results
    }

    func inspectRepository(at url: URL) async throws -> RepositoryInspectionResult {
        guard !results.isEmpty else { return RepositoryInspectionResult(tip: .unknown) }
        return try results.removeFirst().get()
    }
}

private struct MockRepositoryScreenDataProvider: RepositoryScreenDataProviding, Sendable {
    let snapshot: RepositoryScreenSnapshot

    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot {
        snapshot
    }

    func loadMoreCommits(for repository: Repository, skip: Int, maxCount: Int) async throws -> [Commit] {
        []
    }
}

private struct DelayedRepositoryInspector: RepositoryInspecting, Sendable {
    let tipsByPath: [String: RepositoryInspectionResult]
    let delaysByPath: [String: Duration]

    func inspectRepository(at url: URL) async throws -> RepositoryInspectionResult {
        if let delay = delaysByPath[url.path] {
            try? await Task.sleep(for: delay)
        }
        return tipsByPath[url.path] ?? RepositoryInspectionResult(tip: .unknown)
    }
}

private struct PerRepositoryScreenDataProvider: RepositoryScreenDataProviding, Sendable {
    let snapshotsByPath: [String: RepositoryScreenSnapshot]
    let delaysByPath: [String: Duration]

    func loadSnapshot(for repository: Repository?) async throws -> RepositoryScreenSnapshot {
        let path = repository?.url.path ?? ""
        if let delay = delaysByPath[path] {
            try? await Task.sleep(for: delay)
        }
        return snapshotsByPath[path] ?? .testSnapshot
    }

    func loadMoreCommits(for repository: Repository, skip: Int, maxCount: Int) async throws -> [Commit] {
        []
    }
}

private struct MockDiffProvider: DiffProviding, Sendable {
    func fetchDiff(in repositoryURL: URL, for path: String, oldPath: String?) async throws -> DiffDocument {
        DiffDocument(filePath: path, lines: [])
    }

    func fetchCommitDiff(
        in repositoryURL: URL,
        for path: String,
        commitSHA: String
    ) async throws -> DiffDocument {
        DiffDocument(filePath: path, lines: [])
    }

    func submoduleDiff(in repositoryURL: URL, for changedFile: ChangedFile) async throws -> SubmoduleDiffData {
        SubmoduleDiffData(
            path: changedFile.path,
            fullPath: repositoryURL.appendingPathComponent(changedFile.path).path,
            oldSHA: nil,
            newSHA: nil,
            commitChanged: false,
            modifiedChanges: false,
            untrackedChanges: false
        )
    }

    func workingDirectoryImage(in repositoryURL: URL, for path: String) async throws -> ImageDiffContent {
        ImageDiffContent(mediaType: "image/png", base64Contents: "")
    }

    func blobImage(in repositoryURL: URL, for path: String, at ref: String) async throws -> ImageDiffContent {
        ImageDiffContent(mediaType: "image/png", base64Contents: "")
    }
}

private struct DelayedDiffProvider: DiffProviding, Sendable {
    let workingTreeDocsByPath: [String: DiffDocument]
    let workingTreeDelaysByPath: [String: Duration]
    let commitDocsByRequest: [String: DiffDocument]
    let commitDelaysByRequest: [String: Duration]

    func fetchDiff(in repositoryURL: URL, for path: String, oldPath: String?) async throws -> DiffDocument {
        if let delay = workingTreeDelaysByPath[path] {
            try? await Task.sleep(for: delay)
        }
        return workingTreeDocsByPath[path] ?? DiffDocument(filePath: path, lines: [])
    }

    func fetchCommitDiff(
        in repositoryURL: URL,
        for path: String,
        commitSHA: String
    ) async throws -> DiffDocument {
        let key = commitRequestKey(commitSHA: commitSHA, path: path)
        if let delay = commitDelaysByRequest[key] {
            try? await Task.sleep(for: delay)
        }
        return commitDocsByRequest[key] ?? DiffDocument(filePath: path, lines: [])
    }

    func submoduleDiff(in repositoryURL: URL, for changedFile: ChangedFile) async throws -> SubmoduleDiffData {
        SubmoduleDiffData(
            path: changedFile.path,
            fullPath: repositoryURL.appendingPathComponent(changedFile.path).path,
            oldSHA: nil,
            newSHA: nil,
            commitChanged: false,
            modifiedChanges: false,
            untrackedChanges: false
        )
    }

    func workingDirectoryImage(in repositoryURL: URL, for path: String) async throws -> ImageDiffContent {
        ImageDiffContent(mediaType: "image/png", base64Contents: "")
    }

    func blobImage(in repositoryURL: URL, for path: String, at ref: String) async throws -> ImageDiffContent {
        ImageDiffContent(mediaType: "image/png", base64Contents: "")
    }

    private func commitRequestKey(commitSHA: String, path: String) -> String {
        "\(commitSHA)|\(path)"
    }
}

private struct MockCommitInspector: CommitInspecting, Sendable {
    func fetchFiles(for commitSHA: String, in repositoryURL: URL) async throws -> [CommitFile] {
        []
    }
}

private struct DelayedCommitInspector: CommitInspecting, Sendable {
    let filesBySHA: [String: [CommitFile]]
    let delaysBySHA: [String: Duration]

    func fetchFiles(for commitSHA: String, in repositoryURL: URL) async throws -> [CommitFile] {
        if let delay = delaysBySHA[commitSHA] {
            try? await Task.sleep(for: delay)
        }
        return filesBySHA[commitSHA] ?? []
    }
}

private struct DelayedBranchProvider: BranchProviding, Sendable {
    let branchesByRepositoryPath: [String: [Branch]]
    let delaysByRepositoryPath: [String: Duration]

    func fetchBranches(in repositoryURL: URL) async throws -> [Branch] {
        if let delay = delaysByRepositoryPath[repositoryURL.path] {
            try? await Task.sleep(for: delay)
        }
        return branchesByRepositoryPath[repositoryURL.path] ?? []
    }

    func fetchBranchesPointing(at commitish: String, in repositoryURL: URL) async throws -> [Branch] {
        []
    }

    func fetchMergedBranches(into branch: Branch, in repositoryURL: URL) async throws -> [Branch] {
        []
    }
}

private struct DelayedBranchOperator: BranchOperating, Sendable {
    let delaysByRepositoryPath: [String: Duration]

    func createBranch(
        named name: String,
        from startPoint: BranchStartPoint,
        noTrack: Bool,
        in repositoryURL: URL
    ) async throws -> String {
        name
    }

    func switchBranch(to branch: Branch, in repositoryURL: URL) async throws {
        if let delay = delaysByRepositoryPath[repositoryURL.path] {
            try? await Task.sleep(for: delay)
        }
    }

    func deleteLocalBranch(_ branch: Branch, force: Bool, in repositoryURL: URL) async throws {}

    func deleteRemoteBranch(_ branch: Branch, remote: String, in repositoryURL: URL) async throws {}

    func renameBranch(
        _ branch: Branch,
        to newName: String,
        force: Bool,
        in repositoryURL: URL
    ) async throws -> String {
        newName
    }
}

private struct StaticStatusProvider: StatusProviding, Sendable {
    let files: [ChangedFile]

    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile] {
        files
    }
}

private actor MockRepositoryPersistence: RepositoryPersistenceProviding {
    var repositories: [StoredRepository]
    var selectedID: UUID?

    init(
        repositories: [StoredRepository] = [],
        selectedID: UUID? = nil
    ) {
        self.repositories = repositories
        self.selectedID = selectedID
    }

    func saveOrUpdateRepository(path: String) async throws -> StoredRepository {
        let canonicalPath = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let now = Date()
        if let idx = repositories.firstIndex(where: { $0.path == canonicalPath }) {
            let existing = repositories[idx]
            let updated = StoredRepository(
                id: existing.id,
                name: URL(fileURLWithPath: canonicalPath).lastPathComponent,
                path: canonicalPath,
                gitIdentifier: existing.gitIdentifier,
                currentlySelected: true,
                lastOpenedAt: now,
                createdAt: existing.createdAt,
                updatedAt: now,
                existsOnDisk: true
            )
            repositories = repositories.map { item in
                var next = item
                if next.id == updated.id {
                    next = updated
                } else if next.currentlySelected {
                    next = StoredRepository(
                        id: next.id,
                        name: next.name,
                        path: next.path,
                        gitIdentifier: next.gitIdentifier,
                        currentlySelected: false,
                        lastOpenedAt: next.lastOpenedAt,
                        createdAt: next.createdAt,
                        updatedAt: now,
                        existsOnDisk: next.existsOnDisk
                    )
                }
                return next
            }
            selectedID = updated.id
            return updated
        }

        let created = StoredRepository(
            id: UUID(),
            name: URL(fileURLWithPath: canonicalPath).lastPathComponent,
            path: canonicalPath,
            gitIdentifier: nil,
            currentlySelected: true,
            lastOpenedAt: now,
            createdAt: now,
            updatedAt: now,
            existsOnDisk: true
        )
        repositories = repositories.map {
            StoredRepository(
                id: $0.id,
                name: $0.name,
                path: $0.path,
                gitIdentifier: $0.gitIdentifier,
                currentlySelected: false,
                lastOpenedAt: $0.lastOpenedAt,
                createdAt: $0.createdAt,
                updatedAt: now,
                existsOnDisk: $0.existsOnDisk
            )
        } + [created]
        selectedID = created.id
        return created
    }

    func getAllRepositoriesSortedByLastOpened() async throws -> [StoredRepository] {
        repositories.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    func getCurrentlySelectedRepository() async throws -> StoredRepository? {
        repositories.first(where: { $0.currentlySelected })
    }

    func selectRepository(id: UUID) async throws -> StoredRepository? {
        guard let selected = repositories.first(where: { $0.id == id }) else {
            return nil
        }

        let now = Date()
        repositories = repositories.map { item in
            StoredRepository(
                id: item.id,
                name: item.name,
                path: item.path,
                gitIdentifier: item.gitIdentifier,
                currentlySelected: item.id == id,
                lastOpenedAt: item.id == id ? now : item.lastOpenedAt,
                createdAt: item.createdAt,
                updatedAt: now,
                existsOnDisk: item.existsOnDisk
            )
        }
        selectedID = selected.id
        return repositories.first(where: { $0.id == id })
    }

    func removeRepository(id: UUID) async throws {
        repositories.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = nil
        }
    }

    func selectMostRecentlyOpenedRepositoryOnLaunch() async throws -> StoredRepository? {
        guard let chosen = repositories
            .sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt })
            .first(where: { $0.existsOnDisk }) else {
            return nil
        }
        return try await selectRepository(id: chosen.id)
    }
}

private struct MockCommitProvider: CommitProviding, Sendable {
    func commit(in repositoryURL: URL, paths: [String], summary: String, description: String?, options: CommitOptions) async throws {}
    func undoLastCommit(in repositoryURL: URL) async throws {}
}

private struct MockGitClient: GitClientProtocol, Sendable {
    let headByPath: [String: String]

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        if arguments == ["rev-parse", "HEAD"] {
            let value = headByPath[repositoryURL.path] ?? ""
            return GitCommandResult(stdout: value + "\n", stderr: "", exitCode: 0)
        }
        return GitCommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private extension RepositoryScreenSnapshot {
    static var testSnapshot: RepositoryScreenSnapshot {
        RepositoryScreenSnapshot(
            changedFiles: [],
            commits: [],
            userProfile: GitUserProfile(name: "Test User", email: "test@example.com"),
            primaryAction: .publishRepository,
            remoteName: nil,
            forcePushNeeded: false,
            unpushedSHAs: []
        )
    }

    static func snapshot(changedFiles: [ChangedFile]) -> RepositoryScreenSnapshot {
        RepositoryScreenSnapshot(
            changedFiles: changedFiles,
            commits: [],
            userProfile: GitUserProfile(name: "Test User", email: "test@example.com"),
            primaryAction: .publishRepository,
            remoteName: nil,
            forcePushNeeded: false,
            unpushedSHAs: []
        )
    }
}

private extension Branch {
    static func test(
        name: String,
        ref: String? = nil,
        type: BranchType = .local,
        date: Date = .distantPast
    ) -> Branch {
        Branch(
            name: name,
            ref: ref ?? "refs/heads/\(name)",
            tip: BranchTip(
                sha: "abc1234567890",
                shortSHA: "abc1234",
                authorName: "Test User",
                summary: "Test",
                date: date
            ),
            type: type,
            upstream: nil
        )
    }
}

@MainActor
final class RepositoryStoreViewModelTests: XCTestCase {
    func testSelectRepositorySuccessUpdatesBranch() async {
        let inspector = MockRepositoryInspector(
            result: .success(RepositoryInspectionResult(tip: .valid(
                branch: BranchSummary(name: "main", upstream: nil, sha: "abc1234")
            )))
        )
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))

        XCTAssertEqual(RepositoryBranchDisplayFormatter.displayText(for: sut.tip), "main")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testSelectRepositoryFailureSetsError() async {
        enum TestError: Error { case failed }
        let inspector = MockRepositoryInspector(result: .failure(TestError.failed))
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))

        XCTAssertEqual(
            RepositoryBranchDisplayFormatter.displayText(for: sut.tip),
            "No repository selected"
        )
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testDetachedHeadDisplayFormatting() {
        let tip = TipState.detached(sha: "abc1234")
        XCTAssertEqual(
            RepositoryBranchDisplayFormatter.displayText(for: tip),
            "HEAD @ abc1234"
        )
    }

    func testUnbornBranchDisplayFormatting() {
        let tip = TipState.unborn(ref: "main")
        XCTAssertEqual(
            RepositoryBranchDisplayFormatter.displayText(for: tip),
            "main"
        )
    }

    func testBootstrapSelectsMostRecentExistingRepository() async {
        let older = Date().addingTimeInterval(-120)
        let newer = Date().addingTimeInterval(-60)
        let persistence = MockRepositoryPersistence(
            repositories: [
                StoredRepository(
                    id: UUID(),
                    name: "missing",
                    path: "/tmp/missing-repo",
                    gitIdentifier: nil,
                    currentlySelected: false,
                    lastOpenedAt: newer,
                    createdAt: older,
                    updatedAt: newer,
                    existsOnDisk: false
                ),
                StoredRepository(
                    id: UUID(),
                    name: "existing",
                    path: "/tmp/existing-repo",
                    gitIdentifier: nil,
                    currentlySelected: false,
                    lastOpenedAt: older,
                    createdAt: older,
                    updatedAt: older,
                    existsOnDisk: true
                )
            ]
        )

        let inspector = MockRepositoryInspector(result: .success(RepositoryInspectionResult(tip: .valid(
            branch: BranchSummary(name: "main", upstream: nil, sha: "abc1234")
        ))))
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: persistence
        )

        await sut.bootstrapRepositorySelectionOnLaunch()

        XCTAssertEqual(sut.selectedRepository?.url.path, "/tmp/existing-repo")
    }

    func testCoreDataPersistenceUpsertByPath() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let repoPath = tmp.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)
        let storeURL = tmp.appendingPathComponent("RepositoryStore.sqlite")
        let persistence = CoreDataRepositoryPersistence(
            gitClient: MockGitClient(headByPath: [repoPath.path: "abc123"]),
            storeURL: storeURL
        )

        _ = try await persistence.saveOrUpdateRepository(path: repoPath.path)
        _ = try await persistence.saveOrUpdateRepository(path: repoPath.path)
        let all = try await persistence.getAllRepositoriesSortedByLastOpened()

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].path, repoPath.path)
        XCTAssertEqual(all[0].gitIdentifier, "abc123")
    }

    func testCoreDataPersistenceSelectMostRecentSkipsMissing() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let existingRepo = tmp.appendingPathComponent("existing", isDirectory: true)
        try FileManager.default.createDirectory(at: existingRepo, withIntermediateDirectories: true)
        let missingRepo = tmp.appendingPathComponent("missing", isDirectory: true)

        let storeURL = tmp.appendingPathComponent("RepositoryStore.sqlite")
        let persistence = CoreDataRepositoryPersistence(
            gitClient: MockGitClient(headByPath: [:]),
            storeURL: storeURL
        )

        _ = try await persistence.saveOrUpdateRepository(path: existingRepo.path)
        _ = try await persistence.saveOrUpdateRepository(path: missingRepo.path)

        let selected = try await persistence.selectMostRecentlyOpenedRepositoryOnLaunch()

        XCTAssertEqual(selected?.path, existingRepo.path)
    }

    func testSelectRepositoryDropsStaleSnapshotFromOlderSelection() async {
        let repo1 = URL(fileURLWithPath: "/tmp/repo-one", isDirectory: true)
        let repo2 = URL(fileURLWithPath: "/tmp/repo-two", isDirectory: true)
        let inspector = DelayedRepositoryInspector(
            tipsByPath: [
                repo1.path: RepositoryInspectionResult(tip: .valid(
                    branch: BranchSummary(name: "one", upstream: nil, sha: "1111111")
                )),
                repo2.path: RepositoryInspectionResult(tip: .valid(
                    branch: BranchSummary(name: "two", upstream: nil, sha: "2222222")
                ))
            ],
            delaysByPath: [repo1.path: .milliseconds(80), repo2.path: .milliseconds(5)]
        )
        let screenRepository = PerRepositoryScreenDataProvider(
            snapshotsByPath: [
                repo1.path: .snapshot(changedFiles: [ChangedFile(path: "old.txt", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)]),
                repo2.path: .snapshot(changedFiles: [ChangedFile(path: "new.txt", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)])
            ],
            delaysByPath: [repo1.path: .milliseconds(80), repo2.path: .milliseconds(5)]
        )
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: inspector,
            screenRepository: screenRepository,
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )

        let first = Task { await sut.selectRepository(at: repo1) }
        try? await Task.sleep(for: .milliseconds(10))
        let second = Task { await sut.selectRepository(at: repo2) }
        _ = await (first.value, second.value)

        XCTAssertEqual(sut.selectedRepository?.url, repo2)
        XCTAssertEqual(RepositoryBranchDisplayFormatter.displayText(for: sut.tip), "two")
        XCTAssertEqual(sut.changedFiles.map(\.path), ["new.txt"])
        XCTAssertFalse(sut.isLoading)
    }

    func testHistoryHandlerDropsStaleDiffForOlderCommitWithSamePath() async {
        let provider = DelayedDiffProvider(
            workingTreeDocsByPath: [:],
            workingTreeDelaysByPath: [:],
            commitDocsByRequest: [
                "commit-a|README.md": DiffDocument(filePath: "README.md", lines: [DiffDocumentLine(kind: .added, oldNumber: nil, newNumber: 1, text: "old")]),
                "commit-b|README.md": DiffDocument(filePath: "README.md", lines: [DiffDocumentLine(kind: .added, oldNumber: nil, newNumber: 1, text: "new")])
            ],
            commitDelaysByRequest: [
                "commit-a|README.md": .milliseconds(80),
                "commit-b|README.md": .milliseconds(5)
            ]
        )
        let sut = HistoryHandler()
        let repositoryURL = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)

        let first = Task {
            await sut.loadDiff(for: "README.md", commitSHA: "commit-a", using: provider, in: repositoryURL)
        }
        try? await Task.sleep(for: .milliseconds(10))
        let second = Task {
            await sut.loadDiff(for: "README.md", commitSHA: "commit-b", using: provider, in: repositoryURL)
        }
        _ = await (first.value, second.value)

        XCTAssertEqual(sut.selectedCommitFilePath, "README.md")
        XCTAssertEqual(sut.selectedCommitDiffSHA, "commit-b")
        XCTAssertEqual(sut.diffDocument.lines.first?.text, "new")
    }

    func testBranchesViewModelDropsStaleBranchListAfterRepositoryRetarget() async {
        let repo1 = URL(fileURLWithPath: "/tmp/repo-one", isDirectory: true)
        let repo2 = URL(fileURLWithPath: "/tmp/repo-two", isDirectory: true)
        let sut = BranchesViewModel(
            branchProvider: DelayedBranchProvider(
                branchesByRepositoryPath: [
                    repo1.path: [.test(name: "old-branch")],
                    repo2.path: [.test(name: "new-branch")]
                ],
                delaysByRepositoryPath: [repo1.path: .milliseconds(80), repo2.path: .milliseconds(5)]
            ),
            branchOperator: DelayedBranchOperator(delaysByRepositoryPath: [:]),
            statusProvider: StaticStatusProvider(files: [])
        )

        sut.setRepository(repo1, currentBranchName: "old-branch")
        let first = Task { await sut.loadBranches() }
        try? await Task.sleep(for: .milliseconds(10))
        sut.setRepository(repo2, currentBranchName: "new-branch")
        let second = Task { await sut.loadBranches() }
        _ = await (first.value, second.value)

        XCTAssertEqual(sut.repositoryURL, repo2)
        XCTAssertEqual(sut.currentBranchName, "new-branch")
        XCTAssertEqual(sut.localBranches.map(\.name), ["new-branch"])
    }

    func testBranchesViewModelDropsStaleSwitchResultAfterRepositoryRetarget() async {
        let repo1 = URL(fileURLWithPath: "/tmp/repo-one", isDirectory: true)
        let repo2 = URL(fileURLWithPath: "/tmp/repo-two", isDirectory: true)
        let targetBranch = Branch.test(name: "feature")
        let sut = BranchesViewModel(
            branchProvider: DelayedBranchProvider(branchesByRepositoryPath: [:], delaysByRepositoryPath: [:]),
            branchOperator: DelayedBranchOperator(delaysByRepositoryPath: [repo1.path: .milliseconds(80)]),
            statusProvider: StaticStatusProvider(files: [])
        )

        sut.setRepository(repo1, currentBranchName: "main")
        let first = Task { await sut.switchBranch(to: targetBranch) }
        try? await Task.sleep(for: .milliseconds(10))
        sut.setRepository(repo2, currentBranchName: "develop")
        await first.value

        XCTAssertEqual(sut.repositoryURL, repo2)
        XCTAssertEqual(sut.currentBranchName, "develop")
        XCTAssertNil(sut.stashGuardNeeded)
        XCTAssertNil(sut.pendingBranchName)
    }

}

@MainActor
extension RepositoryStoreViewModelTests {
    func testSelectingCurrentRepositoryDoesNotResetState() async {
        let repo = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)
        let inspector = MockRepositoryInspector(
            result: .success(RepositoryInspectionResult(tip: .valid(
                branch: BranchSummary(name: "main", upstream: nil, sha: "abc1234")
            )))
        )
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(
                snapshot: .snapshot(changedFiles: [
                    ChangedFile(
                        path: "README.md",
                        status: .modified,
                        oldPath: nil,
                        isStaged: false,
                        hasConflict: false
                    )
                ])
            ),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )

        await sut.selectRepository(at: repo)
        sut.commitSummary = "Keep this draft"
        let generation = sut.repositorySelectionGeneration

        await sut.selectRepository(at: URL(fileURLWithPath: "/tmp/other/../repo", isDirectory: true))

        XCTAssertEqual(sut.repositorySelectionGeneration, generation)
        XCTAssertEqual(sut.commitSummary, "Keep this draft")
        XCTAssertEqual(sut.selectedChangedFilePath, "README.md")
        XCTAssertFalse(sut.isLoading)
    }

    func testSelectingCurrentRepositoryCanRetryAfterFailedLoad() async {
        enum TestError: Error { case failed }
        let repo = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)
        let inspector = SequencedRepositoryInspector(results: [
            .failure(TestError.failed),
            .success(RepositoryInspectionResult(tip: .valid(
                branch: BranchSummary(name: "main", upstream: nil, sha: "abc1234")
            )))
        ])
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: inspector,
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )

        await sut.selectRepository(at: repo)
        XCTAssertNotNil(sut.errorMessage)

        await sut.selectRepository(at: repo)

        XCTAssertEqual(RepositoryBranchDisplayFormatter.displayText(for: sut.tip), "main")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}

@MainActor
extension RepositoryStoreViewModelTests {
    func testHistoryHandlerDropsStaleFilesForOlderCommitSelection() async {
        let inspector = DelayedCommitInspector(
            filesBySHA: [
                "commit-a": [CommitFile(path: "Old.swift", status: .modified)],
                "commit-b": [CommitFile(path: "New.swift", status: .modified)]
            ],
            delaysBySHA: [
                "commit-a": .milliseconds(80),
                "commit-b": .milliseconds(5)
            ]
        )
        let sut = HistoryHandler()
        let repositoryURL = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)
        sut.selectSingle("commit-a")
        let first = Task {
            await sut.loadFiles(for: "commit-a", using: inspector, in: repositoryURL)
        }
        try? await Task.sleep(for: .milliseconds(10))
        sut.selectSingle("commit-b")
        let second = Task {
            await sut.loadFiles(for: "commit-b", using: inspector, in: repositoryURL)
        }
        _ = await (first.value, second.value)

        XCTAssertEqual(sut.anchorSHA, "commit-b")
        XCTAssertEqual(sut.commitFiles.map(\.path), ["New.swift"])
        XCTAssertEqual(sut.selectedCommitFilePath, "New.swift")
        XCTAssertFalse(sut.isLoadingCommitFiles)
    }

    func testResetPerRepositoryStateClearsConflictResolutionState() {
        let sut = RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: MockRepositoryInspector(
                result: .success(RepositoryInspectionResult(tip: .valid(
                    branch: BranchSummary(name: "main", upstream: nil, sha: "abc1234")
                )))
            ),
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )
        sut.isResolvingConflicts = true
        sut.conflictedFiles = [.withMarkers(path: "README.md", summary: .bothModified, conflictMarkerCount: 2)]
        sut.initialConflictCount = 1
        sut.conflictMergeToolName = "opendiff"
        sut.isConflictActionInProgress = true

        sut.resetPerRepositoryState()

        XCTAssertFalse(sut.isResolvingConflicts)
        XCTAssertTrue(sut.conflictedFiles.isEmpty)
        XCTAssertEqual(sut.initialConflictCount, 0)
        XCTAssertNil(sut.conflictMergeToolName)
        XCTAssertFalse(sut.isConflictActionInProgress)
    }

    func testCanCommitChangesRequiresSelectedFilesOutsideAmendMode() {
        let sut = makeCommitEligibilityViewModel()
        sut.selectedRepository = Repository(url: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))
        sut.commitSummary = "Update README"
        sut.changedFiles = [
            ChangedFile(path: "README.md", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)
        ]
        sut.changedFilesHandler.syncWith(sut.changedFiles)

        XCTAssertTrue(sut.canCommitChanges)

        sut.changedFilesHandler.deselectAll()

        XCTAssertFalse(sut.canCommitChanges)
    }

    func testCanCommitChangesRequiresNonBlankSummary() {
        let sut = makeCommitEligibilityViewModel()
        sut.selectedRepository = Repository(url: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))
        sut.commitSummary = "   "
        sut.changedFiles = [
            ChangedFile(path: "README.md", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)
        ]
        sut.changedFilesHandler.syncWith(sut.changedFiles)

        XCTAssertFalse(sut.canCommitChanges)
    }

    func testCanCommitChangesBlocksUnresolvedConflicts() {
        let sut = makeCommitEligibilityViewModel()
        sut.selectedRepository = Repository(url: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))
        sut.commitSummary = "Resolve work"
        sut.changedFiles = [
            ChangedFile(path: "README.md", status: .unmerged, oldPath: nil, isStaged: false, hasConflict: true)
        ]
        sut.changedFilesHandler.syncWith(sut.changedFiles)

        XCTAssertFalse(sut.canCommitChanges)
    }

    func testCanCommitChangesAllowsAmendWithoutSelectedFilesWhenSummaryIsPresent() {
        let sut = makeCommitEligibilityViewModel()
        sut.selectedRepository = Repository(url: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))
        sut.commitSummary = "Amend previous commit"
        sut.toggleAmendMode()

        XCTAssertTrue(sut.canCommitChanges)
    }

    private func makeCommitEligibilityViewModel() -> RepositoryStoreViewModel {
        RepositoryStoreViewModel(
            logger: GimMacLogger(),
            inspector: MockRepositoryInspector(
                result: .success(RepositoryInspectionResult(tip: .valid(
                    branch: BranchSummary(name: "main", upstream: nil, sha: "abc1234")
                )))
            ),
            screenRepository: MockRepositoryScreenDataProvider(snapshot: .testSnapshot),
            diffProvider: MockDiffProvider(),
            commitInspector: MockCommitInspector(),
            commitProvider: MockCommitProvider(),
            repositoryPersistence: MockRepositoryPersistence()
        )
    }
}

@MainActor
extension RepositoryStoreViewModelTests {
    func testDiffHandlerDropsStaleWorkingTreeDiff() async {
        let provider = DelayedDiffProvider(
            workingTreeDocsByPath: [
                "A.swift": DiffDocument(filePath: "A.swift", lines: [DiffDocumentLine(kind: .added, oldNumber: nil, newNumber: 1, text: "A")]),
                "B.swift": DiffDocument(filePath: "B.swift", lines: [DiffDocumentLine(kind: .added, oldNumber: nil, newNumber: 1, text: "B")])
            ],
            workingTreeDelaysByPath: ["A.swift": .milliseconds(80), "B.swift": .milliseconds(5)],
            commitDocsByRequest: [:],
            commitDelaysByRequest: [:]
        )
        let sut = DiffHandler(diffProvider: provider)
        let repository = Repository(url: URL(fileURLWithPath: "/tmp/repo", isDirectory: true))
        let changedFiles = [
            ChangedFile(path: "A.swift", status: .modified, oldPath: nil, isStaged: false, hasConflict: false),
            ChangedFile(path: "B.swift", status: .modified, oldPath: nil, isStaged: false, hasConflict: false)
        ]

        sut.selectFile("A.swift")
        let first = Task { await sut.loadDiff(in: repository, changedFiles: changedFiles) }
        try? await Task.sleep(for: .milliseconds(10))
        sut.selectFile("B.swift")
        let second = Task { await sut.loadDiff(in: repository, changedFiles: changedFiles) }
        _ = await (first.value, second.value)

        XCTAssertEqual(sut.selectedFilePath, "B.swift")
        XCTAssertEqual(sut.selectedDiffDocument.filePath, "B.swift")
    }

    func testDiffHandlerIncludesHunkHeaderForUntrackedFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "one\ntwo\n".write(to: root.appendingPathComponent("New.swift"), atomically: true, encoding: .utf8)

        let sut = DiffHandler(diffProvider: MockDiffProvider())
        let repository = Repository(url: root)
        let changedFiles = [
            ChangedFile(path: "New.swift", status: .untracked, oldPath: nil, isStaged: false, hasConflict: false)
        ]

        sut.selectFile("New.swift")
        await sut.loadDiff(in: repository, changedFiles: changedFiles)

        XCTAssertEqual(sut.selectedDiffDocument.addedCount, 2)
        XCTAssertEqual(sut.selectedDiffDocument.lines.map(\.kind), [.hunk, .added, .added])
        XCTAssertEqual(sut.selectedDiffDocument.lines.first?.text, "@@ -0,0 +1,2 @@")
        XCTAssertNil(sut.selectedDiffDocument.lines.first?.oldNumber)
        XCTAssertNil(sut.selectedDiffDocument.lines.first?.newNumber)
        XCTAssertEqual(sut.selectedDiffDocument.lines.dropFirst().map(\.text), ["one", "two"])
    }
}
