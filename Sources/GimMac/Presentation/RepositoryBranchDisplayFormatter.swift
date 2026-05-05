import Foundation

enum RepositoryBranchDisplayFormatter {
    static func displayText(for state: RepositoryState) -> String {
        if let currentBranch = state.currentBranch, !currentBranch.isEmpty {
            return currentBranch
        }
        if let detachedHeadShortSHA = state.detachedHeadShortSHA, !detachedHeadShortSHA.isEmpty {
            return "HEAD (detached @ \(detachedHeadShortSHA))"
        }
        return "No repository selected"
    }
}
