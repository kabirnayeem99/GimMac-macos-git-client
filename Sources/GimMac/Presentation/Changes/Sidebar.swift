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

    let viewModel: RepositoryStoreViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filterState = FilterViewState()
    @State private var pendingDiscardPath: String?
    @State private var isConfirmingStashDiscard = false

    private var filteredFiles: [ChangedFile] {
        // Snapshot the checked-paths set once per filter pass so option matching
        // is O(1) per file instead of dispatching through the view model for
        // every file × every selected option.
        let checkedPaths = viewModel.checkedChangedFilePaths
        return viewModel.changedFiles.filter { file in
            matchesFilterText(file) && matchesFilterOptions(file, checkedPaths: checkedPaths)
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

    private func matchesFilterOptions(_ file: ChangedFile, checkedPaths: Set<String>) -> Bool {
        guard !filterState.selectedOptions.isEmpty else {
            return true
        }

        for option in filterState.selectedOptions {
            switch option {
            case .includedInCommit:
                if checkedPaths.contains(file.path) {
                    return true
                }
            case .excludedFromCommit:
                if !checkedPaths.contains(file.path) {
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
                .accessibilityLabel("Filter changed files")
                .accessibilityValue(isAnyFilterOptionSelected ? "Active" : "Off")

                TextField(
                    "Filter",
                    text: Binding(
                        get: { filterState.text },
                        set: { send(.setText($0)) }
                    )
                )
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .accessibilityLabel("Filter changed files")
                    .overlay(alignment: .trailing) {
                        if !filterState.text.isEmpty {
                            Button {
                                send(.setText(""))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                            .accessibilityLabel("Clear filter")
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Group {
                if isAnyFilterOptionSelected {
                    FilterChips(
                        options: FileFilterOption.allCases.filter(filterState.selectedOptions.contains),
                        title: { $0.title },
                        onRemove: { send(.toggleOption($0)) }
                    )
                    .transition(.opacity)
                }
            }
            .motion(
                Motion.feedback,
                reduceMotion: reduceMotion,
                value: filterState.selectedOptions
            )

            ChangedFilesHeader(viewModel: viewModel, filteredCount: filteredFiles.count)

            Divider()

            ChangedFilesListView(
                viewModel: viewModel,
                files: filteredFiles,
                filterValue: filterAnimationValue,
                onRequestDiscard: { pendingDiscardPath = $0 }
            )

            Group {
                if let stash = viewModel.stashEntry {
                    StashPanel(
                        entry: stash,
                        busy: viewModel.isStashOperationInProgress,
                        onRestore: { Task { await viewModel.applyStash() } },
                        onDiscard: { isConfirmingStashDiscard = true }
                    )
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                }
            }
            .motion(Motion.feedback, reduceMotion: reduceMotion, value: viewModel.stashEntry?.id ?? "")

            CommitBox(viewModel: viewModel)
                .padding(.bottom, 10)
        }
        .confirmationDialog(
            discardConfirmationTitle,
            isPresented: Binding(
                get: { pendingDiscardPath != nil },
                set: { if !$0 { pendingDiscardPath = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                if let path = pendingDiscardPath {
                    Task { await viewModel.discardChanges(path: path) }
                }
                pendingDiscardPath = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDiscardPath = nil
            }
        } message: {
            Text("Changes to this file will be lost. This cannot be undone.")
        }
        .confirmationDialog(
            "Discard stashed changes?",
            isPresented: $isConfirmingStashDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                Task { await viewModel.dropStash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The stashed changes will be permanently lost. This cannot be undone.")
        }
    }

    private var discardConfirmationTitle: String {
        guard let path = pendingDiscardPath else { return "Discard changes?" }
        return "Discard changes to \"\(path)\"?"
    }

    private var filterAnimationValue: String {
        let options = filterState.selectedOptions.map(\.rawValue).sorted().joined(separator: ",")
        return "\(filterState.text)|\(options)"
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
