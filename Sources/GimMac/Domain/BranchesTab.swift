import Foundation

/// Top-level tab shown in the branches panel.
///
/// GitHub Desktop equivalent: `BranchesTab` (we omit the `PullRequests`
/// tab — MVP has no GitHub login).
enum BranchesTab: Int, CaseIterable, Sendable {
    case localBranches = 0
    case remoteBranches = 1
}
