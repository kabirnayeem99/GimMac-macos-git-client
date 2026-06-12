import SwiftUI

struct ChangedFilesColumn: View {
    let viewModel: RepositoryStoreViewModel

    // Bridges the view model's path-based selection to the List's id-based
    // native selection (keyboard navigation + focus ring + system highlight).
    private var selection: Binding<ChangedFile.ID?> {
        Binding(
            get: { viewModel.changedFiles.first { $0.path == viewModel.selectedChangedFilePath }?.id },
            set: { newValue in
                guard let id = newValue,
                      let file = viewModel.changedFiles.first(where: { $0.id == id }) else { return }
                viewModel.selectChangedFile(path: file.path)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            CommitDetailsHeader(viewModel: viewModel)

            Divider()

            HStack {
                Text("Changed Files")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(viewModel.changedFilesCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.bar)

            List(viewModel.changedFiles, selection: selection) { file in
                ChangedFileRow(
                    file: file,
                    selected: file.path == viewModel.selectedChangedFilePath,
                    checked: viewModel.isChangedFileChecked(path: file.path),
                    onToggleChecked: {
                        viewModel.toggleChangedFileChecked(path: file.path)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .tag(file.id)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
