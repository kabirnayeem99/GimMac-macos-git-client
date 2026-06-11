import SwiftUI

struct ReorderCommitsSheet: View {
    let onConfirm: ([Commit]) async -> Void
    let onCancel: () -> Void

    @State private var commits: [Commit]
    @State private var isWorking = false

    /// `commits` are passed newest-first (as the history sidebar lists them);
    /// the list shows and returns them in that same orientation.
    init(commits: [Commit], onConfirm: @escaping ([Commit]) async -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _commits = State(initialValue: commits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reorder \(commits.count) Commits")
                    .font(.headline)
                Text("Drag to set the new order, newest at the top. History will be rewritten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List {
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
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Reorder Commits") {
                    isWorking = true
                    let result = commits
                    Task {
                        await onConfirm(result)
                        isWorking = false
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
}
