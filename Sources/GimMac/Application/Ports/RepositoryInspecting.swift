import Foundation

struct RepositoryInspectionResult: Sendable, Equatable {
    let tip: TipState
    let branchName: String?
    let headSHA: String?
    let gitDir: String?
    let isBare: Bool
    let worktreeRoot: URL?
    let inspectedAt: Date

    var hasHead: Bool {
        headSHA != nil
    }

    init(
        tip: TipState,
        branchName: String?,
        headSHA: String?,
        gitDir: String?,
        isBare: Bool,
        worktreeRoot: URL?,
        inspectedAt: Date = Date()
    ) {
        self.tip = tip
        self.branchName = branchName
        self.headSHA = headSHA
        self.gitDir = gitDir
        self.isBare = isBare
        self.worktreeRoot = worktreeRoot
        self.inspectedAt = inspectedAt
    }

    init(tip: TipState) {
        let branchName: String?
        let headSHA: String?
        switch tip {
        case .valid(let branch):
            branchName = branch.name
            headSHA = branch.sha
        case .detached(let sha):
            branchName = nil
            headSHA = sha
        case .unborn(let ref):
            branchName = ref
            headSHA = nil
        case .unknown:
            branchName = nil
            headSHA = nil
        }
        self.init(
            tip: tip,
            branchName: branchName,
            headSHA: headSHA,
            gitDir: nil,
            isBare: false,
            worktreeRoot: nil
        )
    }
}

protocol RepositoryInspecting: Sendable {
    func inspectRepository(at url: URL) async throws -> RepositoryInspectionResult
}
