import SwiftUI

extension GitFileStatus {
    var iconName: String {
        switch self {
        case .modified:
            return "pencil.circle"
        case .added, .untracked:
            return "plus.circle"
        case .deleted:
            return "trash.circle"
        case .renamed:
            return "arrow.left.arrow.right.circle"
        case .copied:
            return "doc.on.doc.circle"
        case .unmerged:
            return "exclamationmark.triangle.circle"
        case .ignored:
            return "eye.slash.circle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var displayName: String {
        switch self {
        case .modified:
            return "Modified"
        case .added:
            return "Added"
        case .untracked:
            return "Untracked"
        case .deleted:
            return "Deleted"
        case .renamed:
            return "Renamed"
        case .copied:
            return "Copied"
        case .unmerged:
            return "Conflict"
        case .ignored:
            return "Ignored"
        case .unknown:
            return "Unknown"
        }
    }

    var rowColor: Color {
        switch self {
        case .modified:
            return Color(.systemOrange)
        case .added, .untracked:
            return Color(.systemGreen)
        case .deleted:
            return Color(.systemRed)
        case .renamed, .copied:
            return Color(.systemBlue)
        case .unmerged:
            return Color(.systemYellow)
        case .ignored, .unknown:
            return .secondary
        }
    }
}
