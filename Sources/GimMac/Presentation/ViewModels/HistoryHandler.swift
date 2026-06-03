import Foundation
import Observation

@MainActor
@Observable
final class HistoryHandler {
    // Anchor is the "origin" row for shift+click range extension.
    // selectedIndices holds all currently highlighted rows (always includes anchorIndex).
    private(set) var anchorIndex = 0
    private(set) var selectedIndices: [Int] = [0]

    private(set) var commitFiles: [CommitFile] = []
    private(set) var isLoadingCommitFiles = false
    private(set) var selectedCommitFilePath: String?

    private(set) var diffDocument: DiffDocument = .empty
    private(set) var isLoadingDiff = false

    // Convenience for callers that only care about the anchor commit.
    var selectedIndex: Int { anchorIndex }

    func selectCommit(at index: Int, extending: Bool = false) {
        if extending && !selectedIndices.isEmpty {
            // Build a contiguous range from the anchor to the clicked row.
            let lo = min(anchorIndex, index)
            let hi = max(anchorIndex, index)
            selectedIndices = Array(lo...hi)
            // Don't reset files — anchor commit content stays visible.
        } else {
            anchorIndex = index
            selectedIndices = [index]
            commitFiles = []
            selectedCommitFilePath = nil
            diffDocument = .empty
        }
    }

    func selectedCommit(in commits: [Commit]) -> Commit? {
        guard !commits.isEmpty else { return nil }
        let safeIndex = min(max(anchorIndex, 0), commits.count - 1)
        return commits[safeIndex]
    }

    func selectedCommits(in commits: [Commit]) -> [Commit] {
        guard !commits.isEmpty else { return [] }
        return selectedIndices.compactMap { idx in
            guard idx >= 0 && idx < commits.count else { return nil }
            return commits[idx]
        }
    }

    func loadFiles(
        for commitSHA: String,
        using inspector: CommitInspecting,
        in repositoryURL: URL
    ) async {
        isLoadingCommitFiles = true
        defer { isLoadingCommitFiles = false }
        let files = (try? await inspector.fetchFiles(for: commitSHA, in: repositoryURL)) ?? []
        guard !Task.isCancelled else { return }
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
