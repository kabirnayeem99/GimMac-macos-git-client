import Foundation

enum RepositoryPrimaryAction: Equatable {
    case fetch
    case commit
    case pull(Int)
    case push(Int)
    case sync(ahead: Int, behind: Int)
    case merge

    var label: String {
        switch self {
        case .fetch:
            return "Fetch origin"
        case .commit:
            return "Commit changes"
        case .pull:
            return "Pull origin"
        case .push:
            return "Push origin"
        case .sync:
            return "Sync branch"
        case .merge:
            return "Continue Merge"
        }
    }

    var badge: String? {
        switch self {
        case .pull(let count), .push(let count):
            return count > 0 ? String(count) : nil
        case .sync(let ahead, let behind):
            return "\(ahead)/\(behind)"
        case .fetch, .commit, .merge:
            return nil
        }
    }

    var subtitle: String {
        switch self {
        case .fetch:
            return "Repository is up to date"
        case .commit:
            return "You have local changes"
        case .pull(let count):
            return "Behind by \(count) commit\(count == 1 ? "" : "s")"
        case .push(let count):
            return "Ahead by \(count) commit\(count == 1 ? "" : "s")"
        case .sync(let ahead, let behind):
            return "Ahead \(ahead), behind \(behind)"
        case .merge:
            return "Resolve conflicts and commit"
        }
    }
}

struct GitUserProfile: Equatable {
    let name: String
    let email: String

    var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }

        if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2)).uppercased()
        }

        return "--"
    }
}

struct RepositoryScreenSnapshot: Equatable {
    let changedFiles: [ChangedFile]
    let commits: [Commit]
    let userProfile: GitUserProfile
    let primaryAction: RepositoryPrimaryAction
    let hasRemote: Bool
}
