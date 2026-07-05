import SwiftUI

/// The scrollable list of changed files. Extracted from `Sidebar` so each
/// row's callback wiring lives in its own view body.
struct ChangedFilesListView: View {
    let viewModel: RepositoryStoreViewModel
    let files: [ChangedFile]
    let filterValue: String
    let onRequestDiscard: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Maps the view model's path-based selection onto the List's id-based
    // selection (ChangedFile.id is a composite of status + path, stable across
    // renames). Native List selection gives keyboard arrow navigation, the
    // focus ring, and the system selection highlight for free. Built once per
    // body evaluation into lookup dictionaries so the Binding's get/set
    // (which List can invoke more than once per render) are O(1) instead of
    // re-scanning `files` linearly on every access.
    private func selectionBinding(pathToID: [String: ChangedFile.ID], idToFile: [ChangedFile.ID: ChangedFile]) -> Binding<ChangedFile.ID?> {
        Binding(
            get: { viewModel.selectedChangedFilePath.flatMap { pathToID[$0] } },
            set: { newValue in
                guard let id = newValue, let file = idToFile[id] else { return }
                viewModel.selectChangedFile(path: file.path)
            }
        )
    }

    var body: some View {
        let pathToID = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0.id) })
        let idToFile = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
        ZStack {
            List(selection: selectionBinding(pathToID: pathToID, idToFile: idToFile)) {
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
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .animation(listAnimation, value: files.map(\.id))

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
