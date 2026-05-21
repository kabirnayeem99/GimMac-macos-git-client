import Foundation
import Observation

@MainActor
@Observable
final class HistoryHandler {
    private(set) var selectedIndex = 0

    private(set) var commitFiles: [CommitFile] = []
    private(set) var isLoadingCommitFiles = false
    private(set) var selectedCommitFilePath: String?

    private(set) var diffDocument: DiffDocument = .empty
    private(set) var isLoadingDiff = false

    func selectCommit(at index: Int) {
        selectedIndex = index
        // Reset per-commit state; callers will reload files + diff.
        commitFiles = []
        selectedCommitFilePath = nil
        diffDocument = .empty
    }

    func selectedCommit(in commits: [Commit]) -> Commit? {
        guard !commits.isEmpty else { return nil }
        let safeIndex = min(max(selectedIndex, 0), commits.count - 1)
        return commits[safeIndex]
    }

    func loadFiles(
        for commitSHA: String,
        using inspector: CommitInspecting,
        in repositoryURL: URL
    ) async {
        isLoadingCommitFiles = true
        defer { isLoadingCommitFiles = false }
        let files = (try? await inspector.fetchFiles(for: commitSHA, in: repositoryURL)) ?? []
        commitFiles = files
        if let first = files.first {
            selectedCommitFilePath = first.path
        } else {
            selectedCommitFilePath = nil
            diffDocument = .empty
        }
    }

    func loadDiff(
        for path: String,
        commitSHA: String,
        using provider: DiffProviding,
        in repositoryURL: URL
    ) async {
        selectedCommitFilePath = path
        isLoadingDiff = true
        defer { isLoadingDiff = false }
        let doc = (try? await provider.fetchCommitDiff(
            in: repositoryURL,
            for: path,
            commitSHA: commitSHA
        )) ?? DiffDocument(filePath: path, lines: [])
        diffDocument = doc
    }
}
