import Foundation

enum ConflictState: Equatable {
    case none
    case merge
    case rebase
    case cherryPick
}

enum RepositoryPrimaryAction: Equatable {
    case publishRepository
    case publishBranch(remote: String)
    case fetch(remote: String)
    case commit
    case pull(remote: String, behind: Int)
    case push(remote: String, ahead: Int)
    case forcePush(remote: String, ahead: Int)
    case sync(remote: String, ahead: Int, behind: Int)
    case merge
    case rebase
    case cherryPick

    var label: String {
        switch self {
        case .publishRepository:
            return "Publish repository"
        case .publishBranch:
            return "Publish branch"
        case .fetch(let remote):
            return "Fetch \(remote)"
        case .commit:
            return "Commit changes"
        case .pull(let remote, _):
            return "Pull \(remote)"
        case .push(let remote, _):
            return "Push \(remote)"
        case .forcePush(let remote, _):
            return "Force push \(remote)"
        case .sync(let remote, _, _):
            return "Sync \(remote)"
        case .merge:
            return "Continue Merge"
        case .rebase:
            return "Continue Rebase"
        case .cherryPick:
            return "Continue Cherry-Pick"
        }
    }

    var badge: String? {
        switch self {
        case .pull(_, let count), .push(_, let count), .forcePush(_, let count):
            return count > 0 ? String(count) : nil
        case .sync(_, let ahead, let behind):
            return "\(ahead)/\(behind)"
        case .publishRepository, .publishBranch, .fetch, .commit, .merge, .rebase, .cherryPick:
            return nil
        }
    }

    var subtitle: String {
        switch self {
        case .publishRepository:
            return "Publish this repository to a remote"
        case .publishBranch(let remote):
            return "Publish this branch to \(remote)"
        case .fetch:
            return "Repository is up to date"
        case .commit:
            return "You have local changes"
        case .pull(_, let count):
            return "Behind by \(count) commit\(count == 1 ? "" : "s")"
        case .push(_, let count):
            return "Ahead by \(count) commit\(count == 1 ? "" : "s")"
        case .forcePush(_, let count):
            return "Force push \(count) commit\(count == 1 ? "" : "s")"
        case .sync(_, let ahead, let behind):
            return "Ahead \(ahead), behind \(behind)"
        case .merge:
            return "Resolve conflicts and commit"
        case .rebase:
            return "Resolve conflicts and continue"
        case .cherryPick:
            return "Resolve conflicts and continue"
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
    let remoteName: String?
    let forcePushNeeded: Bool
    let unpushedSHAs: Set<String>
}

struct CriticalRepositorySnapshot: Equatable {
    let changedFiles: [ChangedFile]
    let commits: [Commit]
    let userProfile: GitUserProfile
    let primaryAction: RepositoryPrimaryAction
    let remoteName: String?
    let forcePushNeeded: Bool
    let unpushedSHAs: Set<String>
}

struct SecondaryRepositorySnapshot: Equatable {
    let userProfile: GitUserProfile
    let primaryAction: RepositoryPrimaryAction
    let remoteName: String?
    let forcePushNeeded: Bool
    let unpushedSHAs: Set<String>
}

extension RepositoryScreenSnapshot {
    var criticalSnapshot: CriticalRepositorySnapshot {
        CriticalRepositorySnapshot(
            changedFiles: changedFiles,
            commits: commits,
            userProfile: userProfile,
            primaryAction: primaryAction,
            remoteName: remoteName,
            forcePushNeeded: forcePushNeeded,
            unpushedSHAs: unpushedSHAs
        )
    }

    var secondarySnapshot: SecondaryRepositorySnapshot {
        SecondaryRepositorySnapshot(
            userProfile: userProfile,
            primaryAction: primaryAction,
            remoteName: remoteName,
            forcePushNeeded: forcePushNeeded,
            unpushedSHAs: unpushedSHAs
        )
    }
}
