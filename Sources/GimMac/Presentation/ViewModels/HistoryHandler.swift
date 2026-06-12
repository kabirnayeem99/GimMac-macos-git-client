import Foundation
import Observation

@MainActor
@Observable
final class HistoryHandler {
    // Selection is keyed by commit SHA so it survives history reloads/reorders.
    // anchorSHA is the last-clicked commit — its files/diff are the ones shown,
    // and it is the origin for shift-range extension (handled natively by List).
    private(set) var selectedSHAs: Set<Commit.ID> = []
    private(set) var anchorSHA: Commit.ID?

    private(set) var commitFiles: [CommitFile] = []
    private(set) var isLoadingCommitFiles = false
    private(set) var selectedCommitFilePath: String?

    private(set) var diffDocument: DiffDocument = .empty
    private(set) var isLoadingDiff = false

    /// Replace the selection with a single commit and reset the file/diff panes.
    func selectSingle(_ sha: Commit.ID) {
        anchorSHA = sha
        selectedSHAs = [sha]
        resetFiles()
    }

    /// Select the newest commit (top of the list), or clear when empty.
    func selectFirst(in commits: [Commit]) {
        if let first = commits.first { selectSingle(first.id) } else { clearSelection() }
    }

    func clearSelection() {
        anchorSHA = nil
        selectedSHAs = []
        resetFiles()
    }

    private func resetFiles() {
        commitFiles = []
        selectedCommitFilePath = nil
        diffDocument = .empty
    }

    /// Apply a new selection set coming from the List binding and resolve the
    /// new anchor (last-clicked commit). Returns the SHA whose files should be
    /// loaded, or nil when no reload is needed (pure deselection, or a
    /// shift-range extend that leaves the existing anchor selected).
    func applySelection(_ newSet: Set<Commit.ID>, in commits: [Commit]) -> Commit.ID? {
        let added = newSet.subtracting(selectedSHAs)
        selectedSHAs = newSet

        if added.count == 1, let clicked = added.first {
            // Plain or Cmd-click of a single new row → that row is the anchor.
            anchorSHA = clicked
            return clicked
        }

        if added.count > 1 {
            // Shift-range extend: keep the current anchor's files if it survives.
            if let anchorSHA, newSet.contains(anchorSHA) { return nil }
            return reanchorTopmost(in: commits)
        }

        // No additions: deselection or no-op.
        if newSet.isEmpty { anchorSHA = nil; return nil }
        if let anchorSHA, newSet.contains(anchorSHA) { return nil }
        return reanchorTopmost(in: commits)
    }

    private func reanchorTopmost(in commits: [Commit]) -> Commit.ID? {
        let newAnchor = commits.first(where: { selectedSHAs.contains($0.id) })?.id
        anchorSHA = newAnchor
        return newAnchor
    }

    func selectedCommit(in commits: [Commit]) -> Commit? {
        if let anchorSHA, let commit = commits.first(where: { $0.id == anchorSHA }) {
            return commit
        }
        // Anchor missing (e.g. it referenced a now-stale SHA): fall back to the
        // topmost still-selected commit before defaulting to the newest.
        return commits.first(where: { selectedSHAs.contains($0.id) }) ?? commits.first
    }

    func selectedCommits(in commits: [Commit]) -> [Commit] {
        commits.filter { selectedSHAs.contains($0.id) }
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
        // Drop a stale result: a newer selection may have superseded this load
        // while the diff was in flight (cancelled task, or selection moved on).
        guard !Task.isCancelled, selectedCommitFilePath == path else { return }
        diffDocument = doc
    }
}
