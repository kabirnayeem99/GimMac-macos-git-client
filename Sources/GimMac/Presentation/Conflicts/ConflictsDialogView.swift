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

/// One conflicted-file row. Mirrors GitHub Desktop's `unmerged-file.tsx`: an
/// "Open in editor" primary action for marker conflicts, a resolution menu for
/// manual (add/delete) conflicts.
private struct UnmergedFileRow: View {
    let viewModel: RepositoryStoreViewModel
    let file: ConflictedFileStatus
    let isResolved: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isResolved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isResolved ? .green : .orange)
                .symbolReplacement(reduceMotion: reduceMotion)
                .motion(Motion.feedback, reduceMotion: reduceMotion, value: isResolved)

            VStack(alignment: .leading, spacing: 2) {
                Text((file.path as NSString).lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(isResolved ? "Resolved" : detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isResolved {
                actions
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var detailText: String {
        if let count = file.conflictMarkerCount, count > 0 {
            return "\(file.summary.label) · \(count) conflict\(count == 1 ? "" : "s")"
        }
        return file.summary.label
    }

    @ViewBuilder
    private var actions: some View {
        if file.summary.hasConflictMarkers {
            Button(openInEditorTitle) {
                viewModel.openInExternalEditor(path: file.path)
            }
            resolutionMenu(includeMarkResolved: true)
        } else if file.summary == .bothDeleted {
            Button("Accept Deletion") {
                Task { await viewModel.acceptConflictDeletion(file) }
            }
        } else {
            resolutionMenu(includeMarkResolved: false)
        }
    }

    private var openInEditorTitle: String {
        if let editor = viewModel.selectedEditorName { return "Open in \(editor)" }
        return "Open File"
    }

    private func resolutionMenu(includeMarkResolved: Bool) -> some View {
        Menu {
            Button("Resolve Using Our Version") {
                Task { await viewModel.resolveConflict(file, using: .ours) }
            }
            Button("Resolve Using Their Version") {
                Task { await viewModel.resolveConflict(file, using: .theirs) }
            }
            if includeMarkResolved {
                Divider()
                Button("Mark as Resolved") {
                    Task { await viewModel.markConflictResolved(file) }
                }
            }
            if viewModel.conflictMergeToolName != nil {
                Divider()
                Button("Open in Merge Tool") {
                    Task { await viewModel.openConflictInMergeTool(file) }
                }
            }
        } label: {
            Text("Resolve")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(viewModel.isConflictActionInProgress)
    }
}
