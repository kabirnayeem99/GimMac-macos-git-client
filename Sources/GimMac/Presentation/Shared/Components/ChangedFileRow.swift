import SwiftUI

struct ChangedFileRow: View {
    let file: ChangedFile
    let selected: Bool
    let checked: Bool
    var recentlyToggled = false
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ignoreFolders: [String] { GitIgnoreRule.ancestorFolders(ofRelativePath: file.path) }
    private var ignorableExtension: String? { GitIgnoreRule.fileExtension(ofRelativePath: file.path) }
    private var isGitignoreFile: Bool {
        (file.path.split(separator: "/").last.map(String.init) ?? file.path) == ".gitignore"
    }

    private var canIgnoreFile: Bool {
        file.status == .untracked && !isGitignoreFile
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleChecked) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.secondary)
                    .symbolReplacement(reduceMotion: reduceMotion)
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: checked)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(checked ? "Exclude from commit" : "Include in commit")
            .accessibilityValue(checked ? "Included" : "Excluded")
            .accessibilityHint("Toggles whether this file is included in the commit")

            Text(file.path)
                .font(.callout.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(file.path)
                .motion(Motion.snappy, reduceMotion: reduceMotion, value: selected)

            Spacer()

            Image(systemName: file.status.iconName)
                .font(.caption.weight(.bold))
                .foregroundStyle(file.status.rowColor)
                .frame(width: 18, height: 18)
                .help(file.status.displayName)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowTint)
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: recentlyToggled)
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
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
        if canIgnoreFile {
            Divider()
            ignoreMenu
        }
        Divider()
        Button("Discard Changes…", role: .destructive, action: onDiscardChanges)
    }

    @ViewBuilder
    private var ignoreMenu: some View {
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

    private var rowTint: Color {
        if recentlyToggled {
            return file.status.rowColor.opacity(0.16)
        }
        if selected {
            return Color.accentColor.opacity(0.12)
        }
        return .clear
    }
}
