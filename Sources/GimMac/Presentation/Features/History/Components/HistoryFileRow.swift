import SwiftUI

struct HistoryFileRow: View {
    let file: CommitFile
    var onRevealInFinder: () -> Void = {}
    var onOpenInEditor: () -> Void = {}
    var onOpenWithDefault: () -> Void = {}
    var onCopyPath: () -> Void = {}
    var onCopyRelativePath: () -> Void = {}
    var editorName: String?

    private var canOpenWorkingTreeFile: Bool {
        file.status != .deleted
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(file.path)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(file.path)

            Spacer(minLength: 8)

            Image(systemName: file.status.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(file.status.rowColor)
                .frame(width: 16, height: 16)
                .help(file.status.displayName)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(file.status.displayName), \(file.path)")
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if canOpenWorkingTreeFile {
            Button("Reveal in Finder", action: onRevealInFinder)
            Button("Open in \(editorName ?? "External Editor")", action: onOpenInEditor)
            Button("Open with Default Program", action: onOpenWithDefault)
            Divider()
        }
        Button("Copy File Path", action: onCopyPath)
        Button("Copy Relative File Path", action: onCopyRelativePath)
    }
}
