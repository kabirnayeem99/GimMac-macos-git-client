import SwiftUI

struct SquashCommitsSheet: View {
    let commits: [Commit]
    let onConfirm: (String) async -> Void
    let onCancel: () -> Void

    @State private var message: String
    @State private var isSquashing = false

    init(commits: [Commit], onConfirm: @escaping (String) async -> Void, onCancel: @escaping () -> Void) {
        self.commits = commits
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _message = State(initialValue: commits.map(\.summary).joined(separator: "\n\n"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Squash \(commits.count) Commits")
                    .font(.headline)
                Text("These commits will be combined into one. Edit the message below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $message)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Squash Commits") {
                    isSquashing = true
                    Task {
                        await onConfirm(message)
                        isSquashing = false
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSquashing)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 460)
    }
}
