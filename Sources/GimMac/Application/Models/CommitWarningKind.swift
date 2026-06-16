import Foundation

enum CommitWarningKind: Equatable, Sendable {
    case detachedHead
    case unborn

    var message: String {
        switch self {
        case .detachedHead:
            return "You are in a detached HEAD state. This commit will not belong to any branch."
        case .unborn:
            return "This branch has not been created yet. Your first commit will create it."
        }
    }
}
