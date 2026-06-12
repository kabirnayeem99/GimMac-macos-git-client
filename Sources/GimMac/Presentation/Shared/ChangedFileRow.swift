import SwiftUI

struct ChangedFileRow: View {
    let file: ChangedFile
    let selected: Bool
    let checked: Bool
    let onToggleChecked: () -> Void
    var onDiscardChanges: () -> Void = {}
    var onRevealInFinder: () -> Void = {}
    var onOpenInEditor: () -> Void = {}
    var onOpenWithDefault: () -> Void = {}
    var onCopyPath: () -> Void = {}
    var onCopyRelativePath: () -> Void = {}
    var onIgnoreFile: () -> Void = {}
    var onIgnoreFolder: (String) -> Void = { _ in }
    var onIgnoreExtension: () -> Void = {}
    var editorName: String?

    private var ignoreFolders: [String] { GitIgnoreRule.ancestorFolders(ofRelativePath: file.path) }
    private var ignorableExtension: String? { GitIgnoreRule.fileExtension(ofRelativePath: file.path) }
    private var isGitignoreFile: Bool {
        (file.path.split(separator: "/").last.map(String.init) ?? file.path) == ".gitignore"
    }

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
        case .unmerged:
            return "exclamationmark.triangle"
        case .ignored:
            return "eye.slash"
        case .unknown:
            return "questionmark.circle"
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
        case .renamed:
            return Color(.systemBlue)
        case .unmerged:
            return Color(.systemYellow)
        case .ignored, .unknown:
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleChecked) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checked ? "Included in commit" : "Excluded from commit")

            Text(file.path)
                .font(.callout.weight(selected ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            Image(systemName: statusIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
            if !isGitignoreFile {
                Divider()
                Menu("Ignore") {
                    Button("Ignore File (Add to .gitignore)", action: onIgnoreFile)
                    if !ignoreFolders.isEmpty {
                        Menu("Ignore Folder (Add to .gitignore)") {
                            ForEach(ignoreFolders, id: \.self) { folder in
                                Button(folder) { onIgnoreFolder(folder) }
                            }
                        }
                    }
                    if let ext = ignorableExtension {
                        Button("Ignore All *.\(ext) Files (Add to .gitignore)", action: onIgnoreExtension)
                    }
                }
            }
            Divider()
            Button("Discard Changes…", role: .destructive, action: onDiscardChanges)
        }
    }
}
