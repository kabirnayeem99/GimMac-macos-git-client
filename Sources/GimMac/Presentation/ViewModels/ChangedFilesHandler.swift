import Foundation
import Observation

@MainActor
@Observable
final class ChangedFilesHandler {
    private(set) var checkedPaths: Set<String> = []
    private(set) var recentlyToggled: Set<String> = []
    private(set) var hasLoadedOnce = false
    private(set) var animatesNextFileChange = false

    @ObservationIgnored private var loadedFileIDsByPath: [String: ChangedFile.ID] = [:]
    @ObservationIgnored private var toggleResetTasks: [String: Task<Void, Never>] = [:]

    private static let maximumAnimatedPathChanges = 40

    func syncWith(_ changedFiles: [ChangedFile]) {
        let latestFileIDsByPath = Dictionary(
            uniqueKeysWithValues: changedFiles.map { ($0.path, $0.id) }
        )
        let loadedPaths = Set(loadedFileIDsByPath.keys)
        let latestPaths = Set(latestFileIDsByPath.keys)
        let changedPathCount = loadedPaths.symmetricDifference(latestPaths).count
        let isFullReplacement = !loadedPaths.isEmpty &&
            !latestPaths.isEmpty &&
            loadedPaths.isDisjoint(with: latestPaths)
        let containsIdentityChange = latestFileIDsByPath.contains { path, fileID in
            loadedFileIDsByPath[path].map { $0 != fileID } ?? false
        }

        animatesNextFileChange = hasLoadedOnce &&
            !isFullReplacement &&
            !containsIdentityChange &&
            changedPathCount <= Self.maximumAnimatedPathChanges
        hasLoadedOnce = true
        loadedFileIDsByPath = latestFileIDsByPath

        let retained = checkedPaths.intersection(latestPaths)
        let added = latestPaths.subtracting(retained)
        checkedPaths = retained.union(added)
    }

    func isChecked(_ path: String) -> Bool {
        checkedPaths.contains(path)
    }

    func toggle(_ path: String) {
        if checkedPaths.contains(path) {
            checkedPaths.remove(path)
        } else {
            checkedPaths.insert(path)
        }

        signalToggle(for: path)
    }

    func selectAll(paths: [String]) {
        checkedPaths = Set(paths)
    }

    func deselectAll() {
        checkedPaths = []
    }

    private func signalToggle(for path: String) {
        recentlyToggled.insert(path)
        toggleResetTasks[path]?.cancel()
        toggleResetTasks[path] = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.recentlyToggled.remove(path)
            self?.toggleResetTasks[path] = nil
        }
    }

    func resetForRepositoryChange() {
        checkedPaths = []
        recentlyToggled = []
        hasLoadedOnce = false
        animatesNextFileChange = false
        loadedFileIDsByPath = [:]
        toggleResetTasks.values.forEach { $0.cancel() }
        toggleResetTasks = [:]
    }
}
