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
    struct ChangedFileDiffLogMessages {
        let scheduled: String?
        let started: String
        let finished: String
        let cancelled: String
    }

    func selectChangedFile(path: String) {
        diffHandler.selectFile(path)
        guard let repository = selectedRepository else { return }
        let tag = logger.tag("changes.file-diff-load", parent: nil, metadata: [
            "repository": repository.url.lastPathComponent,
            "path": path
        ])
        Task {
            await scheduleChangedFileDiffLoad(
                for: repository,
                path: path,
                changedFiles: changedFiles,
                inspection: currentInspection,
                tag: tag,
                messages: ChangedFileDiffLogMessages(
                    scheduled: "Changed file diff load scheduled",
                    started: "Changed file diff load started",
                    finished: "Changed file diff load finished",
                    cancelled: "Changed file diff load cancelled"
                )
            )
        }
    }

    func isChangedFileChecked(path: String) -> Bool {
        changedFilesHandler.isChecked(path)
    }

    func wasChangedFileRecentlyToggled(path: String) -> Bool {
        changedFilesHandler.recentlyToggled.contains(path)
    }

    var animatesChangedFileUpdates: Bool {
        changedFilesHandler.animatesNextFileChange
    }

    var hasLoadedChangedFilesOnce: Bool {
        changedFilesHandler.hasLoadedOnce
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
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "io.github.kabirnayeem99.gimmac.settings.useCustomEditor"),
           let data = defaults.data(forKey: "io.github.kabirnayeem99.gimmac.settings.customEditor"),
           let custom = try? JSONDecoder().decode(CustomIntegration.self, from: data),
           !custom.path.isEmpty {
            let appURL = URL(fileURLWithPath: custom.path)
            if let bundle = Bundle(url: appURL) {
                return (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? appURL.deletingPathExtension().lastPathComponent
            }
            return appURL.deletingPathExtension().lastPathComponent
        }
        
        guard let bundleID = defaults.string(forKey: ExternalEditorPreferences.selectedEditorKey),
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: appURL) else { return nil }
        return (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
    }

    func openInExternalEditor(path: String) {
        guard let repository = selectedRepository else { return }
        let fileURL = repository.url.appendingPathComponent(path)
        
        let defaults = UserDefaults.standard
        let useCustomEditor = defaults.bool(forKey: "io.github.kabirnayeem99.gimmac.settings.useCustomEditor")
        
        if useCustomEditor,
           let data = defaults.data(forKey: "io.github.kabirnayeem99.gimmac.settings.customEditor"),
           let custom = try? JSONDecoder().decode(CustomIntegration.self, from: data),
           !custom.path.isEmpty {
            let appURL = URL(fileURLWithPath: custom.path)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            var args: [String] = []
            let rawArgs = custom.arguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for arg in rawArgs {
                if arg.contains(CustomIntegration.targetPathArgument) {
                    args.append(arg.replacingOccurrences(of: CustomIntegration.targetPathArgument, with: fileURL.path))
                } else {
                    args.append(arg)
                }
            }
            config.arguments = args
            NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
            return
        }
        
        guard let bundleID = defaults.string(forKey: ExternalEditorPreferences.selectedEditorKey),
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

    func copyCommitHash(_ hash: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
    }

    func scheduleChangedFileDiffLoad(
        for repository: Repository,
        path: String,
        changedFiles: [ChangedFile],
        inspection: RepositoryInspectionResult? = nil,
        tag: LogFlowTag?,
        messages: ChangedFileDiffLogMessages,
        waitForCompletion: Bool = false
    ) async {
        changedFileDiffTask?.cancel()
        if let scheduledMessage = messages.scheduled {
            logger.info(
                scheduledMessage,
                category: .diff,
                metadata: ["repository": repository.url.lastPathComponent, "path": path],
                tag: tag
            )
        }

        let task = Task { [weak self] in
            let startedAt = Self.nowMilliseconds()
            self?.logger.info(
                messages.started,
                category: .diff,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "path": path,
                    "changed_files": String(changedFiles.count)
                ],
                tag: tag
            )
            await self?.diffHandler.loadDiff(
                in: repository,
                changedFiles: changedFiles,
                inspection: inspection
            )
            guard !Task.isCancelled else {
                self?.logger.warning(
                    messages.cancelled,
                    category: .diff,
                    metadata: [
                        "repository": repository.url.lastPathComponent,
                        "path": path,
                        "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                    ],
                    tag: tag
                )
                return
            }
            self?.logger.info(
                messages.finished,
                category: .diff,
                metadata: [
                    "repository": repository.url.lastPathComponent,
                    "path": path,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
        }
        changedFileDiffTask = task
        if waitForCompletion {
            await task.value
        }
    }
}
