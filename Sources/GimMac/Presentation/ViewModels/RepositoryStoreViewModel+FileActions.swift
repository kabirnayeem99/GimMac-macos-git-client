import AppKit
import Foundation

// Per-file UI affordances: diff selection, checkbox toggling, Finder/editor/shell
// integrations, and clipboard helpers.
//
// Architecture note: AppKit is imported here only for `NSWorkspace` /
// `NSPasteboard` — small, native-only OS integrations that avoid creating a
// separate service for one-line side effects.

@MainActor
extension RepositoryStoreViewModel {
    func selectChangedFile(path: String) {
        diffHandler.selectFile(path)
        guard let repository = selectedRepository else { return }
        Task { [weak self] in
            await self?.diffHandler.loadDiff(in: repository, changedFiles: self?.changedFiles ?? [])
        }
    }

    func isChangedFileChecked(path: String) -> Bool {
        changedFilesHandler.isChecked(path)
    }

    func toggleChangedFileChecked(path: String) {
        changedFilesHandler.toggle(path)
    }

    func selectAllChangedFiles() {
        changedFilesHandler.selectAll(paths: changedFiles.map(\.path))
    }

    func deselectAllChangedFiles() {
        changedFilesHandler.deselectAll()
    }

    func revealInFinder(path: String) {
        guard let repository = selectedRepository else { return }
        let fileURL = repository.url.appendingPathComponent(path)
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    var selectedEditorName: String? {
        guard let bundleID = UserDefaults.standard.string(forKey: ExternalEditorPreferences.selectedEditorKey),
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: appURL) else { return nil }
        return (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
    }

    func openInExternalEditor(path: String) {
        guard let repository = selectedRepository else { return }
        let fileURL = repository.url.appendingPathComponent(path)
        guard let bundleID = UserDefaults.standard.string(forKey: ExternalEditorPreferences.selectedEditorKey),
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSWorkspace.shared.open(fileURL)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
    }

    func openWithDefaultProgram(path: String) {
        guard let repository = selectedRepository else { return }
        NSWorkspace.shared.open(repository.url.appendingPathComponent(path))
    }

    func copyFilePath(path: String) {
        guard let repository = selectedRepository else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(repository.url.appendingPathComponent(path).path, forType: .string)
    }

    func copyRelativeFilePath(path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}
