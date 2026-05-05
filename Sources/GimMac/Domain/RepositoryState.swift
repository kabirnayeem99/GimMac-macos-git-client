import Foundation

struct RepositoryState: Equatable {
    var currentBranch: String?
    var detachedHeadShortSHA: String?

    var branchDisplayText: String {
        if let currentBranch, !currentBranch.isEmpty {
            return currentBranch
        }
        if let detachedHeadShortSHA, !detachedHeadShortSHA.isEmpty {
            return "HEAD (detached @ \(detachedHeadShortSHA))"
        }
        return "No repository selected"
    }
}
