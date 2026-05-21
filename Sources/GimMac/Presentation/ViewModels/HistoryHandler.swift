import Foundation
import Observation

@MainActor
@Observable
final class HistoryHandler {
    private(set) var selectedIndex = 0

    func selectCommit(at index: Int) {
        selectedIndex = index
    }

    func selectedCommit(in commits: [Commit]) -> Commit? {
        guard !commits.isEmpty else { return nil }
        let safeIndex = min(max(selectedIndex, 0), commits.count - 1)
        return commits[safeIndex]
    }
}
