import Foundation

/// Where a new branch should be created from.
///
/// Translates to a git revspec at the Data layer.
/// GitHub Desktop equivalent: `StartPoint` enum.
enum BranchStartPoint: Equatable, Sendable {
    case currentBranch
    /// `origin/HEAD` or the configured default branch.
    case defaultBranch
    case head
    case branch(Branch)
    case commit(sha: String)
}
