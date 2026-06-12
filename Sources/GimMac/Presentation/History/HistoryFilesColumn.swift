import SwiftUI

struct HistoryFilesColumn: View {
    let viewModel: RepositoryStoreViewModel

    // Bridges the view model's path-based selection onto the List's id-based
    // selection (CommitFile.id == path). Native List selection provides keyboard
    // arrow navigation, the focus ring, and the system highlight for free.
    private var selection: Binding<CommitFile.ID?> {
        Binding(
            get: { viewModel.historyFiles.first { $0.path == viewModel.selectedHistoryFilePath }?.id },
            set: { newValue in
                guard let id = newValue,
                      let file = viewModel.historyFiles.first(where: { $0.id == id }) else { return }
                viewModel.selectHistoryFile(path: file.path)
            }
        )
    }

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

            List(viewModel.historyFiles, selection: selection) { file in
                HistoryFileRow(
                    file: file,
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
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .tag(file.id)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if viewModel.historyFiles.isEmpty {
                    ContentUnavailableView(
                        "No Changed Files",
                        systemImage: "doc.text",
                        description: Text("This commit has no file changes.")
                    )
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct HistoryFileRow: View {
    let file: CommitFile
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

    private var statusName: String {
        switch file.status {
        case .modified: return "Modified"
        case .added, .untracked: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
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
        case .renamed:
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
