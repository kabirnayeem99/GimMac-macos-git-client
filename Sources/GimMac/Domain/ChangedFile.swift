import Foundation

enum GitFileStatus: String, Sendable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case unmerged = "U"
    case ignored = "!"
    case unknown = "X"
}

/// Sub-status for a changed file that is itself a git submodule, derived from the
/// porcelain v2 `<sub>` field (`S<c><m><u>`). Mirrors GitHub Desktop's
/// `SubmoduleStatus` (`models/status.ts`). `nil` on a normal file.
struct SubmoduleStatus: Equatable, Sendable {
    /// The submodule's checked-out commit differs from the gitlink (`c == 'C'`).
    let commitChanged: Bool
    /// The submodule has tracked, modified content (`m == 'M'`).
    let modifiedChanges: Bool
    /// The submodule has untracked files (`u == 'U'`).
    let untrackedChanges: Bool
}

struct ChangedFile: Identifiable, Equatable, Sendable {
    var id: String { "\(status.rawValue):\(oldPath ?? path)" }
    let path: String
    let status: GitFileStatus
    let oldPath: String?
    let isStaged: Bool
    let hasConflict: Bool
    let submoduleStatus: SubmoduleStatus?

    init(
        path: String,
        status: GitFileStatus,
        oldPath: String?,
        isStaged: Bool,
        hasConflict: Bool,
        submoduleStatus: SubmoduleStatus? = nil
    ) {
        self.path = path
        self.status = status
        self.oldPath = oldPath
        self.isStaged = isStaged
        self.hasConflict = hasConflict
        self.submoduleStatus = submoduleStatus
    }
}
