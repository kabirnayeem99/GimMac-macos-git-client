import Foundation

/// Distinguishes between local working branches and remote-tracking branches.
///
/// GitHub Desktop equivalent: `BranchType` enum in `app/src/models/branch.ts`.
enum BranchType: Equatable, Sendable {
    case local
    case remote(remoteName: String)
}

/// The tip commit of a branch. Captured from `git for-each-ref`.
///
/// GitHub Desktop equivalent: `IBranchTip`.
struct BranchTip: Equatable, Sendable {
    let sha: String
    let shortSHA: String
    let authorName: String
    /// Commit subject line (first line of the message).
    let summary: String
    let date: Date
}

/// A Git branch — either a local working branch or a remote tracking ref.
///
/// Distinct from `BranchSummary` (which is used solely for the toolbar's
/// current-branch display). `Branch` carries the full metadata needed for
/// the branches panel, sorting by recency, and ahead/behind comparisons.
///
/// GitHub Desktop equivalent: `Branch` class in `app/src/models/branch.ts`.
struct Branch: Identifiable, Equatable, Sendable {
    /// Identity uses the full ref so that local `refs/heads/foo` and remote
    /// `refs/remotes/origin/foo` never collide in table-view diffing.
    var id: String { ref }

    /// Short name, e.g. `main`, `feature/foo`, `origin/main`.
    let name: String
    /// Full ref, e.g. `refs/heads/main` or `refs/remotes/origin/main`.
    let ref: String
    let tip: BranchTip
    let type: BranchType
    /// Tracking branch short name, e.g. `origin/main` — `nil` if no upstream.
    let upstream: String?

    var isLocal: Bool {
        if case .local = type { return true }
        return false
    }

    var remoteName: String? {
        guard case .remote(let r) = type else { return nil }
        return r
    }

    /// For a remote branch `origin/feature/foo` returns `feature/foo`.
    /// For locals returns `name` unchanged.
    var nameWithoutRemote: String {
        guard let r = remoteName else { return name }
        let prefix = r + "/"
        guard name.hasPrefix(prefix) else { return name }
        return String(name.dropFirst(prefix.count))
    }

    /// The remote name carried by the upstream, e.g. `origin` for an upstream of
    /// `origin/main`. `nil` when there is no upstream or it lacks a remote
    /// prefix. GitHub Desktop equivalent: `Branch.upstreamRemoteName`.
    var upstreamRemoteName: String? {
        guard let upstream, let slash = upstream.firstIndex(of: "/") else { return nil }
        return String(upstream[..<slash])
    }

    /// The upstream branch name without its remote prefix, e.g. `main` for
    /// `origin/main` or `thing/foo` for `origin/thing/foo`. `nil` when there is
    /// no upstream or it lacks a remote prefix.
    /// GitHub Desktop equivalent: `Branch.upstreamWithoutRemote`.
    var upstreamWithoutRemote: String? {
        guard let upstream, let slash = upstream.firstIndex(of: "/") else { return nil }
        return String(upstream[upstream.index(after: slash)...])
    }
}
