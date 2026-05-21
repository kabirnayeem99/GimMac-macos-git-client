import Foundation

enum RepositoryBranchDisplayFormatter {
    static func displayText(for tip: TipState) -> String {
        switch tip {
        case .unknown:
            return "No repository selected"
        case .unborn(let ref):
            return ref
        case .detached(let sha):
            return "HEAD @ \(sha)"
        case .valid(let branch):
            return branch.name
        }
    }
}
