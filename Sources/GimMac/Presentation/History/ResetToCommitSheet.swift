import SwiftUI

struct ResetToCommitSheet: View {
    let commit: Commit
    let onConfirm: (ResetMode) async -> Void
    let onCancel: () -> Void

    @State private var mode: ResetMode = .mixed
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reset to Commit")
                    .font(.headline)
                Text("Move the current branch to \(commit.shortHash) — \(commit.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Picker("Mode", selection: $mode) {
                Text("Mixed — keep working tree, reset index").tag(ResetMode.mixed)
                Text("Soft — keep working tree and index").tag(ResetMode.soft)
                Text("Hard — discard all changes").tag(ResetMode.hard)
            }
            .pickerStyle(.radioGroup)

            if mode == .hard {
                Label(
                    "Hard reset permanently discards all uncommitted changes and any commits after \(commit.shortHash).",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button(mode == .hard ? "Reset (Discard Changes)" : "Reset") {
                    isWorking = true
                    Task {
                        await onConfirm(mode)
                        isWorking = false
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isWorking)
                .buttonStyle(.borderedProminent)
                .tint(mode == .hard ? .red : nil)
            }
        }
        .padding(16)
        .frame(width: 440)
    }
}
