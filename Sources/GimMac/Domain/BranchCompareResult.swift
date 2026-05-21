import Foundation

/// Commit-count delta between two refs.
///
/// GitHub Desktop equivalent: `IAheadBehind`.
struct AheadBehind: Equatable, Sendable {
    let ahead: Int
    let behind: Int
}

/// Result of comparing two branches: ahead/behind counts plus the commits
/// in `compare` that are not in `base`.
///
/// GitHub Desktop equivalent: `ICompareResult`.
struct BranchCompareResult: Equatable, Sendable {
    let base: Branch
    let compare: Branch
    let aheadBehind: AheadBehind
    /// Commits reachable from `compare` but not `base`, newest first.
    let commits: [Commit]
}
