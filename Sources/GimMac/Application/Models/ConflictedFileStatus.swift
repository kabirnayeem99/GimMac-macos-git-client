import Foundation

/// Which side of a conflict the user chose to keep. Maps directly to git's
/// `--ours` / `--theirs` checkout arguments. Mirrors GitHub Desktop's
/// `ManualConflictResolution` enum (`manual-conflict-resolution.ts`).
enum ManualConflictResolution: String, Sendable, Equatable {
    case ours
    case theirs
}

/// Classification of an unmerged file, derived from the `XY` status code in
/// git's porcelain output. Mirrors GitHub Desktop's `UnmergedEntrySummary`
/// (`models/status.ts`).
///
/// `XY` code → case:
/// `UU` both modified, `AA` both added, `DD` both deleted,
/// `AU` added by us, `UA` added by them, `DU` deleted by us, `UD` deleted by them.
enum UnmergedEntrySummary: Sendable, Equatable {
    case bothModified
    case bothAdded
    case bothDeleted
    case addedByUs
    case addedByThem
    case deletedByUs
    case deletedByThem

    /// True when both sides contributed content, so the working-tree file holds
    /// `<<<<<<< ======= >>>>>>>` markers the user edits by hand. These map to
    /// GitHub Desktop's `ConflictsWithMarkers`; the rest are `ManualConflict`.
    var hasConflictMarkers: Bool {
        self == .bothModified || self == .bothAdded
    }

    /// A short, human-readable description of the conflict kind for the UI.
    var label: String {
        switch self {
        case .bothModified: return "Modified on both branches"
        case .bothAdded: return "Added on both branches"
        case .bothDeleted: return "Deleted on both branches"
        case .addedByUs: return "Added by us, deleted by them"
        case .addedByThem: return "Added by them, deleted by us"
        case .deletedByUs: return "Deleted by us, modified by them"
        case .deletedByThem: return "Modified by us, deleted by them"
        }
    }
}

/// The status of a single conflicted file in an in-progress merge / rebase /
/// cherry-pick. Mirrors GitHub Desktop's `ConflictedFileStatus`
/// (`ConflictsWithMarkers | ManualConflict`).
enum ConflictedFileStatus: Sendable, Equatable, Identifiable {
    /// A text conflict with `<<<<<<<` markers in the working tree.
    /// `conflictMarkerCount` comes from `git diff --check`.
    case withMarkers(path: String, summary: UnmergedEntrySummary, conflictMarkerCount: Int)
    /// An add/delete-style conflict resolved by choosing a side, not by editing.
    case manual(path: String, summary: UnmergedEntrySummary)

    var id: String { path }

    var path: String {
        switch self {
        case let .withMarkers(path, _, _): return path
        case let .manual(path, _): return path
        }
    }

    var summary: UnmergedEntrySummary {
        switch self {
        case let .withMarkers(_, summary, _): return summary
        case let .manual(_, summary): return summary
        }
    }

    /// Marker count for marker-based conflicts; `nil` for manual conflicts.
    var conflictMarkerCount: Int? {
        switch self {
        case let .withMarkers(_, _, count): return count
        case .manual: return nil
        }
    }
}
