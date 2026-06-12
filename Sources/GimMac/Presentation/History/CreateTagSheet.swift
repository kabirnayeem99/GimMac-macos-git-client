import SwiftUI

struct CreateTagSheet: View {
    let commit: Commit
    let onConfirm: (String, String?) async -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var message = ""
    @State private var isWorking = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validation: BranchNameValidation {
        BranchesViewModel.validateBranchName(name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create Tag")
                    .font(.headline)
                Text("Tag commit \(commit.shortHash) — \(commit.summary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TextField("Tag name (e.g. v1.0.0)", text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Tag name")

            if !trimmedName.isEmpty, let reason = validation.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Color(.systemRed))
            }

            TextField("Message (optional — annotated tag)", text: $message)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Tag message")

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Create Tag") {
                    isWorking = true
                    let messageToSend = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await onConfirm(trimmedName, messageToSend.isEmpty ? nil : messageToSend)
                        isWorking = false
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!validation.isValid || isWorking)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
