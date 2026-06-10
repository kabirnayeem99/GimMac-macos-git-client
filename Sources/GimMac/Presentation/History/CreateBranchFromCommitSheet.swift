import SwiftUI

struct CreateBranchFromCommitSheet: View {
    let commit: Commit
    let onConfirm: (String) async -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var isWorking = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create Branch from Commit")
                    .font(.headline)
                Text("New branch will start at \(commit.shortHash) — \(commit.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("Branch name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Create Branch") {
                    isWorking = true
                    Task {
                        await onConfirm(trimmedName)
                        isWorking = false
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(trimmedName.isEmpty || isWorking)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
