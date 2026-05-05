import SwiftUI

struct ChangedFilesColumn: View {
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

                Text("\(viewModel.changedFilesCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.bar)

            List(viewModel.changedFiles) { file in
                ChangedFileRow(
                    file: file,
                    selected: file.path == viewModel.selectedChangedFilePath,
                    checked: viewModel.isChangedFileChecked(path: file.path),
                    onToggleChecked: {
                        viewModel.toggleChangedFileChecked(path: file.path)
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectChangedFile(path: file.path)
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
