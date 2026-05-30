import SwiftUI

struct HistoryFilesColumn: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            CommitDetailsHeader(viewModel: viewModel)

            Divider()

            HStack {
                Text("Changed Files")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.historyFiles.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.bar)

            List(viewModel.historyFiles) { file in
                HistoryFileRow(
                    file: file,
                    selected: file.path == viewModel.selectedHistoryFilePath,
                    onRevealInFinder: {
                        viewModel.revealInFinder(path: file.path)
                    },
                    onOpenInEditor: {
                        viewModel.openInExternalEditor(path: file.path)
                    },
                    onOpenWithDefault: {
                        viewModel.openWithDefaultProgram(path: file.path)
                    },
                    onCopyPath: {
                        viewModel.copyFilePath(path: file.path)
                    },
                    onCopyRelativePath: {
                        viewModel.copyRelativeFilePath(path: file.path)
                    },
                    editorName: viewModel.selectedEditorName
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectHistoryFile(path: file.path)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct HistoryFileRow: View {
    let file: CommitFile
    let selected: Bool
    var onRevealInFinder: () -> Void = {}
    var onOpenInEditor: () -> Void = {}
    var onOpenWithDefault: () -> Void = {}
    var onCopyPath: () -> Void = {}
    var onCopyRelativePath: () -> Void = {}
    var editorName: String? = nil

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
            return .orange
        case .added, .untracked:
            return .green
        case .deleted:
            return .red
        case .renamed:
            return .blue
        case .unmerged:
            return .yellow
        case .ignored, .unknown:
            return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(file.path)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Color.white.opacity(0.9) : statusColor)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor : Color.clear)
        .foregroundStyle(selected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
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
