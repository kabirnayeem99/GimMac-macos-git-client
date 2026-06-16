import SwiftUI

/// Merge-conflict resolution sheet. Native equivalent of GitHub Desktop's
/// `conflicts-dialog.tsx`: lists the unmerged files for an in-progress merge /
/// rebase / cherry-pick, offers per-file resolution, and gates Continue until
/// every conflict is resolved.
///
/// Stateful and live (the file set shrinks as conflicts are resolved), so this
/// binds the `RepositoryStoreViewModel` directly — matching `DiffViewer` /
/// `CommitBox` rather than the one-shot value+closure sheets.
struct ConflictsDialogView: View {
    let viewModel: RepositoryStoreViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayedFiles: [ConflictedFileStatus] {
        guard let resolved = viewModel.recentlyResolvedConflict,
              !viewModel.conflictedFiles.contains(where: { $0.path == resolved.path }) else {
            return viewModel.conflictedFiles
        }
        return viewModel.conflictedFiles + [resolved]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            fileList
            Divider()
            footer
        }
        .frame(width: 560, height: 460)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Resolve \(viewModel.conflictOperationLabel) Conflicts")
                .font(.headline)
            Text(progressText)
                .font(.caption)
                .foregroundStyle(viewModel.canContinueConflictOperation ? Color.green : .secondary)
                .contentTransition(.numericText(value: Double(viewModel.resolvedConflictCount)))
                .motion(Motion.feedback, reduceMotion: reduceMotion, value: viewModel.resolvedConflictCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var progressText: String {
        if viewModel.canContinueConflictOperation {
            return "All conflicts resolved."
        }
        return "\(viewModel.resolvedConflictCount) of \(viewModel.initialConflictCount) conflicts resolved."
    }

    // MARK: - File list

    private var fileList: some View {
        ScrollView {
            Group {
                if displayedFiles.isEmpty {
                    Text("No remaining conflicts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                        .transition(Motion.contentCrossfade(reduceMotion: reduceMotion))
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedFiles) { file in
                            UnmergedFileRow(
                                viewModel: viewModel,
                                file: file,
                                isResolved: viewModel.recentlyResolvedConflict?.path == file.path
                            )
                            Divider()
                        }
                    }
                    .transition(Motion.contentCrossfade(reduceMotion: reduceMotion))
                    .animation(
                        Motion.resolve(Motion.snappy, reduceMotion: reduceMotion),
                        value: displayedFiles.map(\.path)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Abort \(viewModel.conflictOperationLabel)", role: .destructive) {
                Task { await viewModel.abortConflictOperation() }
            }
            .disabled(viewModel.isConflictActionInProgress)

            Spacer()

            Button("Cancel") {
                viewModel.cancelConflictResolution()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Continue \(viewModel.conflictOperationLabel)") {
                Task { await viewModel.continueConflictOperation() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canContinueConflictOperation || viewModel.conflictContinueOutcome == .success)
            .overlay {
                if viewModel.conflictContinueOutcome == .success {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .symbolReplacement(reduceMotion: reduceMotion)
                        .transition(.opacity)
                }
            }
            .motion(Motion.feedback, reduceMotion: reduceMotion, value: viewModel.conflictContinueOutcome)
        }
        .padding(16)
    }
}
