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
            if viewModel.conflictedFiles.isEmpty {
                Text("No remaining conflicts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.conflictedFiles) { file in
                        UnmergedFileRow(viewModel: viewModel, file: file)
                        Divider()
                    }
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
            .disabled(!viewModel.canContinueConflictOperation)
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text((file.path as NSString).lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actions
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
