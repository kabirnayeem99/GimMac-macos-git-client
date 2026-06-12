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
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                let allChecked = !viewModel.changedFiles.isEmpty &&
                    viewModel.checkedChangedFilePaths.count == viewModel.changedFilesCount
                let someChecked = !viewModel.checkedChangedFilePaths.isEmpty && !allChecked

                Button {
                    if allChecked {
                        viewModel.deselectAllChangedFiles()
                    } else {
                        viewModel.selectAllChangedFiles()
                    }
                } label: {
                    Image(systemName: allChecked
                          ? "checkmark.square.fill"
                          : (someChecked ? "minus.square.fill" : "square"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.changedFiles.isEmpty)
                .help(allChecked ? "Deselect all" : "Select all")
                .accessibilityLabel(allChecked ? "Deselect all files" : "Select all files")
                .accessibilityValue(allChecked ? "All selected" : (someChecked ? "Some selected" : "None selected"))

                Text("^[\(viewModel.changedFilesCount) changed file](inflect: true)")
                    .font(.callout.weight(.medium))

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.bar)

            Divider()

            ChangedFilesListView(
                viewModel: viewModel,
                files: filteredFiles,
                onRequestDiscard: { pendingDiscardPath = $0 }
            )

            if let stash = viewModel.stashEntry {
                StashPanel(
                    entry: stash,
                    busy: viewModel.isStashOperationInProgress,
                    onRestore: { Task { await viewModel.applyStash() } },
                    onDiscard: { isConfirmingStashDiscard = true }
                )
            }

            CommitBox(viewModel: viewModel)
        }
        .background(.thinMaterial)
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

/// The scrollable list of changed files. Extracted from `Sidebar` so each
/// row's callback wiring lives in its own view body.
private struct ChangedFilesListView: View {
    let viewModel: RepositoryStoreViewModel
    let files: [ChangedFile]
    let onRequestDiscard: (String) -> Void

    // Maps the view model's path-based selection onto the List's id-based
    // selection (ChangedFile.id is a composite of status + path, stable across
    // renames). Native List selection gives keyboard arrow navigation, the
    // focus ring, and the system selection highlight for free.
    private var selection: Binding<ChangedFile.ID?> {
        Binding(
            get: { files.first { $0.path == viewModel.selectedChangedFilePath }?.id },
            set: { newValue in
                guard let id = newValue,
                      let file = files.first(where: { $0.id == id }) else { return }
                viewModel.selectChangedFile(path: file.path)
            }
        )
    }

    var body: some View {
        List(files, selection: selection) { file in
            ChangedFileRow(
                file: file,
                selected: file.path == viewModel.selectedChangedFilePath,
                checked: viewModel.isChangedFileChecked(path: file.path),
                onToggleChecked: { viewModel.toggleChangedFileChecked(path: file.path) },
                onDiscardChanges: { onRequestDiscard(file.path) },
                onRevealInFinder: { viewModel.revealInFinder(path: file.path) },
                onOpenInEditor: { viewModel.openInExternalEditor(path: file.path) },
                onOpenWithDefault: { viewModel.openWithDefaultProgram(path: file.path) },
                onCopyPath: { viewModel.copyFilePath(path: file.path) },
                onCopyRelativePath: { viewModel.copyRelativeFilePath(path: file.path) },
                onIgnoreFile: { Task { await viewModel.ignoreFile(path: file.path) } },
                onIgnoreFolder: { folder in Task { await viewModel.ignoreFolder(folder) } },
                onIgnoreExtension: { Task { await viewModel.ignoreExtension(forPath: file.path) } },
                editorName: viewModel.selectedEditorName
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .tag(file.id)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct StashPanel: View {
    let entry: StashEntry
    let busy: Bool
    let onRestore: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tray.full")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Stashed Changes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(entry.message)
                .font(.callout)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button("Restore", action: onRestore)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(busy)
                Button("Discard", role: .destructive, action: onDiscard)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(busy)
                Spacer()
            }
        }
        .padding(10)
        .liquidGlassBackground(fallbackMaterial: .bar)
        .overlay(alignment: .top) { Divider() }
    }
}
