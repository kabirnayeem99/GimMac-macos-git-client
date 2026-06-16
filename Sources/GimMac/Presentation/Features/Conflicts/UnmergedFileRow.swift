import SwiftUI

/// One conflicted-file row with editor and resolution actions.
struct UnmergedFileRow: View {
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
