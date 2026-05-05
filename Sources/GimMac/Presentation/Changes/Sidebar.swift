import SwiftUI

struct Sidebar: View {
    private enum FileFilterOption: String, CaseIterable, Hashable {
        case includedInCommit
        case excludedFromCommit
        case newFiles
        case modifiedFiles
        case deletedFiles

        var title: String {
            switch self {
            case .includedInCommit:
                return "Included in commit"
            case .excludedFromCommit:
                return "Excluded from commit"
            case .newFiles:
                return "New files"
            case .modifiedFiles:
                return "Modified files"
            case .deletedFiles:
                return "Deleted files"
            }
        }
    }

    private struct FilterViewState {
        var text = ""
        var selectedOptions: Set<FileFilterOption> = []
    }

    private enum FilterIntent {
        case setText(String)
        case toggleOption(FileFilterOption)
        case clearAll
    }

    @Binding var selectedTab: Int
    let viewModel: RepositoryStoreViewModel
    @State private var filterState = FilterViewState()

    private var filteredFiles: [ChangedFile] {
        viewModel.changedFiles.filter { file in
            matchesFilterText(file) && matchesFilterOptions(file)
        }
    }

    private var isAnyFilterOptionSelected: Bool {
        !filterState.selectedOptions.isEmpty
    }

    private func matchesFilterText(_ file: ChangedFile) -> Bool {
        guard !filterState.text.isEmpty else {
            return true
        }

        return file.path.localizedCaseInsensitiveContains(filterState.text)
    }

    private func matchesFilterOptions(_ file: ChangedFile) -> Bool {
        guard !filterState.selectedOptions.isEmpty else {
            return true
        }

        for option in filterState.selectedOptions {
            switch option {
            case .includedInCommit:
                if viewModel.isChangedFileChecked(path: file.path) {
                    return true
                }
            case .excludedFromCommit:
                if !viewModel.isChangedFileChecked(path: file.path) {
                    return true
                }
            case .newFiles:
                if file.status == .added || file.status == .untracked {
                    return true
                }
            case .modifiedFiles:
                if file.status == .modified || file.status == .renamed {
                    return true
                }
            case .deletedFiles:
                if file.status == .deleted {
                    return true
                }
            }
        }

        return false
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
                Menu {
                    if isAnyFilterOptionSelected {
                        Button("Clear Filters") {
                            send(.clearAll)
                        }

                        Divider()
                    }

                    ForEach(FileFilterOption.allCases, id: \.self) { option in
                        Button {
                            send(.toggleOption(option))
                        } label: {
                            HStack {
                                Text(option.title)
                                Spacer()
                                if filterState.selectedOptions.contains(option) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: isAnyFilterOptionSelected ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Filter changed files")

                TextField(
                    "Filter",
                    text: Binding(
                        get: { filterState.text },
                        set: { send(.setText($0)) }
                    )
                )
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
            .background(.bar)

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

            CommitBox(viewModel: viewModel)
        }
        .background(.thinMaterial)
    }

    private func send(_ intent: FilterIntent) {
        filterState = reduce(state: filterState, intent: intent)
    }

    private func reduce(state: FilterViewState, intent: FilterIntent) -> FilterViewState {
        var nextState = state

        switch intent {
        case .setText(let text):
            nextState.text = text
        case .toggleOption(let option):
            if nextState.selectedOptions.contains(option) {
                nextState.selectedOptions.remove(option)
            } else {
                nextState.selectedOptions.insert(option)
            }
        case .clearAll:
            nextState.selectedOptions = []
        }

        return nextState
    }
}
