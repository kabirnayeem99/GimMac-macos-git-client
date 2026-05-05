import SwiftUI

struct Sidebar: View {
    @Binding var selectedTab: Int
    let viewModel: RepositoryStoreViewModel
    @State private var filterText = ""

    private var filteredFiles: [ChangedFile] {
        guard !filterText.isEmpty else {
            return viewModel.changedFiles
        }

        return viewModel.changedFiles.filter { file in
            file.path.localizedCaseInsensitiveContains(filterText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Changes").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                Button {
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                TextField("Filter", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("\(viewModel.changedFilesCount) changed file\(viewModel.changedFilesCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 30)

            Divider()

            List(filteredFiles) { file in
                ChangedFileRow(
                    file: file,
                    selected: file.path == viewModel.selectedChangedFilePath,
                    checked: viewModel.isChangedFileChecked(path: file.path),
                    onToggleChecked: {
                        viewModel.toggleChangedFileChecked(path: file.path)
                    }
                )
                .onTapGesture {
                    viewModel.selectChangedFile(path: file.path)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            CommitBox(viewModel: viewModel)
        }
        .background(.thinMaterial)
    }
}
