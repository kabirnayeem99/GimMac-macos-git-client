import Foundation
import Observation

@MainActor
@Observable
final class ChangedFilesHandler {
    private(set) var checkedPaths: Set<String> = []

    func syncWith(_ changedFiles: [ChangedFile]) {
        let latestPaths = Set(changedFiles.map(\.path))
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
    }
}
