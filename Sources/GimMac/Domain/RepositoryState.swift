import Foundation

struct RepositoryState: Equatable {
    var currentBranch: String?
    var detachedHeadShortSHA: String?
    var headHash: String? = nil
}
