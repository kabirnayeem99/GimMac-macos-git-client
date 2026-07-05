import SwiftUI

struct ReorderCommitsSheet: View {
    let onConfirm: ([Commit]) async -> Bool
    let onCancel: () -> Void

    @State private var commits: [Commit]
    @State private var selectedCommitID: Commit.ID?
    @State private var isWorking = false

    /// `commits` are passed newest-first (as the history sidebar lists them);
    /// the list shows and returns them in that same orientation.
    init(commits: [Commit], onConfirm: @escaping ([Commit]) async -> Bool, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _commits = State(initialValue: commits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reorder \(commits.count) Commits")
                    .font(.headline)
                Text("Drag to set the new order, newest at the top. You can also use Move Up and Move Down. History will be rewritten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Label(
                "Reordering rewrites commit SHAs. Only continue if these commits have not been shared.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)

            List(selection: $selectedCommitID) {
                ForEach(commits) { commit in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Text(commit.shortHash)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(commit.summary)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }
                .onMove { source, destination in
                    commits.move(fromOffsets: source, toOffset: destination)
                }
            }
            .frame(minHeight: 180)

            HStack(spacing: 8) {
                Button("Move Up") {
                    moveSelection(offset: -1)
                }
                .disabled(!canMoveSelection(offset: -1) || isWorking)

                Button("Move Down") {
                    moveSelection(offset: 1)
                }
                .disabled(!canMoveSelection(offset: 1) || isWorking)

                Spacer()
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Reorder Commits") {
                    isWorking = true
                    let result = commits
                    Task {
                        let didSucceed = await onConfirm(result)
                        isWorking = false
                        if didSucceed {
                            onCancel()
                        }
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isWorking)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 480)
    }

    private func canMoveSelection(offset: Int) -> Bool {
        guard let index = selectedIndex else { return false }
        let destination = index + offset
        return commits.indices.contains(index) && commits.indices.contains(destination)
    }

    private func moveSelection(offset: Int) {
        guard canMoveSelection(offset: offset), let index = selectedIndex else { return }
        let destination = index + offset
        let commit = commits.remove(at: index)
        commits.insert(commit, at: destination)
        selectedCommitID = commit.id
    }

    private var selectedIndex: Int? {
        guard let selectedCommitID else { return nil }
        return commits.firstIndex { $0.id == selectedCommitID }
    }
}
