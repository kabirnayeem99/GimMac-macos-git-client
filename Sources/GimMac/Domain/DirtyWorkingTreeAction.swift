import Foundation

/// User choice when attempting to switch branches with a dirty working tree.
///
/// GitHub Desktop equivalent: `StashAndSwitchBranchDialog` button outcomes.
enum DirtyWorkingTreeAction: Equatable, Sendable {
    case stashChanges
    case discardChanges
    case cancel
}
