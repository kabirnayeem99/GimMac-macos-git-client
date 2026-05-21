import Foundation
import Observation

@MainActor
@Observable
final class DiffHandler {
    private let diffProvider: DiffProviding

    private(set) var selectedDiffDocument = DiffDocument.empty
    private(set) var isLoadingDiff = false
    private(set) var selectedFilePath: String?

    init(diffProvider: DiffProviding) {
        self.diffProvider = diffProvider
    }

    func selectFile(_ path: String) {
        selectedFilePath = path
    }

    func clearSelection() {
        selectedFilePath = nil
        selectedDiffDocument = .empty
    }

    func loadDiff(in repository: Repository, changedFiles: [ChangedFile]) async {
        guard let path = selectedFilePath else {
            selectedDiffDocument = .empty
            return
        }

        if let changedFile = changedFiles.first(where: { $0.path == path }),
           changedFile.status == .untracked {
            selectedDiffDocument = await loadUntrackedFileDiff(repositoryURL: repository.url, path: path)
            return
        }

        isLoadingDiff = true
        defer { isLoadingDiff = false }

        do {
            selectedDiffDocument = try await diffProvider.fetchDiff(in: repository.url, for: path)
        } catch {
            selectedDiffDocument = DiffDocument(filePath: path, lines: [])
        }
    }

    private func loadUntrackedFileDiff(repositoryURL: URL, path: String) async -> DiffDocument {
        let fileURL = repositoryURL.appendingPathComponent(path)
        let content = await Task.detached(priority: .userInitiated) {
            try? String(contentsOf: fileURL, encoding: .utf8)
        }.value

        guard let content else {
            return DiffDocument(filePath: path, lines: [])
        }

        let lines = content.components(separatedBy: .newlines)
        let diffLines = lines.enumerated().map { index, line in
            DiffDocumentLine(kind: .added, oldNumber: nil, newNumber: index + 1, text: line)
        }

        return DiffDocument(filePath: path, lines: diffLines)
    }
}
