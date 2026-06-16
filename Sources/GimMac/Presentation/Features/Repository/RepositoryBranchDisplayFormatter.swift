import Foundation

enum RepositoryBranchDisplayFormatter {
    static func displayText(for tip: TipState) -> String {
        switch tip {
        case .unknown:
            return "No repository selected"
        case .unborn(let ref):
            return ref
        case .detached(let sha):
            // The model carries the full SHA; show the abbreviated form.
            return "HEAD @ \(String(sha.prefix(7)))"
        case .valid(let branch):
            return branch.name
        }
    }
}
