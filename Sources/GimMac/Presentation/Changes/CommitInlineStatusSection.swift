import SwiftUI

struct CommitInlineStatusSection: View {
    let viewModel: RepositoryStoreViewModel
    let reduceMotion: Bool

    private var state: InlineStatusState {
        InlineStatusState(
            hasUnresolvedConflicts: viewModel.hasUnresolvedConflicts,
            warning: viewModel.commitWarning?.message,
            error: viewModel.errorMessage,
            outcome: viewModel.commitOutcome
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.hasUnresolvedConflicts {
                Label("Resolve all conflicts before committing.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(.systemOrange))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit blocked: Resolve all conflicts before committing.")
            }

            if let warning = viewModel.commitWarning {
                Label(warning.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color(.systemOrange))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit warning: \(warning.message)")
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "xmark.circle.fill")
                    .foregroundStyle(Color(.systemRed))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit error: \(error)")
                    .accessibilityIdentifier("statusLabel")
            }

            if viewModel.commitOutcome == .success {
                Label("Commit created successfully.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(.systemGreen))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit status: Commit created successfully.")
                    .accessibilityIdentifier("commitSuccessStatus")
            }
        }
        .font(.caption)
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: state)
    }
}

private struct InlineStatusState: Equatable {
    let hasUnresolvedConflicts: Bool
    let warning: String?
    let error: String?
    let outcome: OpOutcome
}
