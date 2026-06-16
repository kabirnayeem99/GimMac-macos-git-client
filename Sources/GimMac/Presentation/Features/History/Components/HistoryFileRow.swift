import SwiftUI

struct HistoryFileRow: View {
    let file: CommitFile
    var onRevealInFinder: () -> Void = {}
    var onOpenInEditor: () -> Void = {}
    var onOpenWithDefault: () -> Void = {}
    var onCopyPath: () -> Void = {}
    var onCopyRelativePath: () -> Void = {}
    var editorName: String?

    private var statusIcon: String {
        switch file.status {
        case .modified:
            return "pencil"
        case .added, .untracked:
            return "plus.circle"
        case .deleted:
            return "trash"
        case .renamed:
            return "arrow.left.arrow.right"
        case .copied:
            return "doc.on.doc"
        case .unmerged:
            return "exclamationmark.triangle"
        case .ignored:
            return "eye.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var statusName: String {
        switch file.status {
        case .modified: return "Modified"
        case .added, .untracked: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .unmerged: return "Conflicted"
        case .ignored: return "Ignored"
        case .unknown: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .modified:
            return Color(.systemOrange)
        case .added, .untracked:
            return Color(.systemGreen)
        case .deleted:
            return Color(.systemRed)
        case .renamed, .copied:
            return Color(.systemBlue)
        case .unmerged:
            return Color(.systemRed)
        case .ignored, .unknown:
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(file.path)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(statusName) — \(file.path)")
        .contextMenu {
            Button("Reveal in Finder", action: onRevealInFinder)
            if let name = editorName {
                Button("Open in \(name)", action: onOpenInEditor)
            } else {
                Button("Open in External Editor", action: onOpenInEditor)
            }
            Button("Open with Default Program", action: onOpenWithDefault)
            Divider()
            Button("Copy File Path", action: onCopyPath)
            Button("Copy Relative File Path", action: onCopyRelativePath)
        }
    }
}
