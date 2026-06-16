import SwiftUI

struct HistoryFilesColumn: View {
    let viewModel: RepositoryStoreViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .contentTransition(.numericText())
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: viewModel.historyFiles.count)
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
