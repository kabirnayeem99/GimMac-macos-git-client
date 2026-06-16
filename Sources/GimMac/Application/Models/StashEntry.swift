import Foundation

struct StashEntry: Identifiable, Equatable, Sendable {
    let id: String          // selector ref, e.g. "stash@{0}" — usable as a git ref
    let index: Int          // 0-based position in the stash stack
    let message: String     // subject (%s)
    let branchName: String
    let createdAt: Date?     // commit time (%ct); nil when unparsable

    init(id: String, index: Int = 0, message: String, branchName: String, createdAt: Date? = nil) {
        self.id = id
        self.index = index
        self.message = message
        self.branchName = branchName
        self.createdAt = createdAt
    }
}
