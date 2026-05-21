import Foundation

enum TipState: Equatable {
    case unknown
    case unborn(ref: String)
    case detached(sha: String)
    case valid(branch: BranchSummary)
}

struct BranchSummary: Equatable {
    let name: String
    let upstream: String?
    let sha: String
}
