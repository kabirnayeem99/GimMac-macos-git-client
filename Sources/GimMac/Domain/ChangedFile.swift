import Foundation

enum GitFileStatus: String, Sendable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"
    case unmerged = "U"
    case ignored = "!"
    case unknown = "X"
}

struct ChangedFile: Identifiable, Equatable, Sendable {
    var id: String { path }
    let path: String
    let status: GitFileStatus
    let oldPath: String? // For renames
}
