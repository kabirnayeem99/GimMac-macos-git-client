import Foundation
import Observation

/// Drives the (post-MVP) compare-branches screen. Declared now so callers can
/// reference it incrementally without a follow-up rename pass.
@MainActor
@Observable
final class BranchCompareViewModel {
    var baseBranch: Branch?
    var compareBranch: Branch?
    private(set) var result: BranchCompareResult?
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    var repositoryURL: URL?

    private let compareProvider: BranchCompareProviding

    init(compareProvider: BranchCompareProviding) {
        self.compareProvider = compareProvider
    }

    func compare() async {
        guard let repositoryURL,
              let base = baseBranch,
              let compare = compareBranch else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            self.result = try await compareProvider.compareBranches(
                base: base,
                compare: compare,
                in: repositoryURL
            )
        } catch {
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
        }
    }
}
