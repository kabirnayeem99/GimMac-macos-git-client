import Foundation
import Observation

@MainActor
@Observable
final class RepositoryStoreViewModel {
    private let inspector: RepositoryInspecting

    private(set) var selectedRepository: Repository?
    private(set) var repositoryState = RepositoryState(currentBranch: nil, detachedHeadShortSHA: nil)
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(inspector: RepositoryInspecting) {
        self.inspector = inspector
    }

    func selectRepository(at url: URL) async {
        isLoading = true
        errorMessage = nil
        selectedRepository = Repository(url: url)
        defer { isLoading = false }

        do {
            repositoryState = try await inspector.inspectRepository(at: url)
        } catch {
            repositoryState = RepositoryState(currentBranch: nil, detachedHeadShortSHA: nil)
            errorMessage = error.localizedDescription
        }
    }
}
