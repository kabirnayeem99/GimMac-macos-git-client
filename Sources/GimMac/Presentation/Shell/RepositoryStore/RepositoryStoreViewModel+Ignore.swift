import Foundation

// `.gitignore` rule generation and appending.

@MainActor
extension RepositoryStoreViewModel {
    func ignoreFile(path: String) async {
        await appendIgnore([GitIgnoreRule.fileRule(forRelativePath: path)])
    }

    func ignoreFolder(_ folder: String) async {
        await appendIgnore([GitIgnoreRule.folderRule(forRelativePath: folder)])
    }

    func ignoreExtension(forPath path: String) async {
        guard let fileExtension = GitIgnoreRule.fileExtension(ofRelativePath: path) else { return }
        await appendIgnore([GitIgnoreRule.extensionRule(forExtension: fileExtension)])
    }

    private func appendIgnore(_ entries: [String]) async {
        guard let repository = selectedRepository, let gitIgnoreProvider else { return }
        errorMessage = nil
        do {
            try await gitIgnoreProvider.appendIgnoreEntries(entries, in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
