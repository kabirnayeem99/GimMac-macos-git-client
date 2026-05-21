import Foundation

struct StashEntry: Identifiable, Equatable, Sendable {
    let id: String          // e.g. "stash@{0}"
    let message: String
    let branchName: String
}
