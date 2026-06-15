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

private struct FilterChips<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    let onRemove: (Option) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onRemove(option)
                    } label: {
                        Label(title(option), systemImage: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityLabel("Remove \(title(option)) filter")
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 8)
    }
}

private struct ChangedFilesHeader: View {
    let viewModel: RepositoryStoreViewModel
    let filteredCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allChecked: Bool {
        !viewModel.changedFiles.isEmpty &&
            viewModel.checkedChangedFilePaths.count == viewModel.changedFilesCount
    }

    private var someChecked: Bool {
        !viewModel.checkedChangedFilePaths.isEmpty && !allChecked
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if allChecked {
                    viewModel.deselectAllChangedFiles()
                } else {
                    viewModel.selectAllChangedFiles()
                }
            } label: {
                Image(systemName: selectionSymbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .symbolReplacement(reduceMotion: reduceMotion)
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: selectionSymbol)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.changedFiles.isEmpty)
            .help(allChecked ? "Deselect all" : "Select all")
            .accessibilityLabel(allChecked ? "Deselect all files" : "Select all files")
            .accessibilityValue(selectionAccessibilityValue)

            Text(countLabel)
                .font(.callout.weight(.medium))
                .contentTransition(.numericText(value: Double(filteredCount)))
                .motion(Motion.feedback, reduceMotion: reduceMotion, value: filteredCount)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.bar)
    }

    private var selectionSymbol: String {
        allChecked ? "checkmark.square.fill" : (someChecked ? "minus.square.fill" : "square")
    }

    private var selectionAccessibilityValue: String {
        allChecked ? "All selected" : (someChecked ? "Some selected" : "None selected")
    }

    private var countLabel: String {
        let totalCount = viewModel.changedFilesCount
        guard filteredCount != totalCount else {
            return "\(filteredCount) changed \(filteredCount == 1 ? "file" : "files")"
        }
        return "\(filteredCount) of \(totalCount) changed \(totalCount == 1 ? "file" : "files")"
    }
}

/// The scrollable list of changed files. Extracted from `Sidebar` so each
/// row's callback wiring lives in its own view body.
private struct ChangedFilesListView: View {
    let viewModel: RepositoryStoreViewModel
    let files: [ChangedFile]
    let filterValue: String
    let onRequestDiscard: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        ZStack {
            List(selection: selection) {
                ForEach(files) { file in
                    ChangedFileRow(
                        file: file,
                        selected: file.path == viewModel.selectedChangedFilePath,
                        checked: viewModel.isChangedFileChecked(path: file.path),
                        recentlyToggled: viewModel.wasChangedFileRecentlyToggled(path: file.path),
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(listAnimation, value: files.map(\.id))

            if files.isEmpty, viewModel.hasLoadedChangedFilesOnce {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(emptyStateDescription)
                )
                .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                .allowsHitTesting(false)
            }
        }
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: filterValue)
        .animation(listAnimation, value: files.isEmpty)
    }

    private var listAnimation: Animation? {
        guard viewModel.animatesChangedFileUpdates else { return nil }
        return Motion.resolve(Motion.feedback, reduceMotion: reduceMotion)
    }

    private var emptyStateTitle: String {
        filterValue == "|" ? "No Changed Files" : "No Matching Files"
    }

    private var emptyStateDescription: String {
        if filterValue == "|" {
            return "Your working copy is clean."
        }
        return "Try changing or clearing the current filters."
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
