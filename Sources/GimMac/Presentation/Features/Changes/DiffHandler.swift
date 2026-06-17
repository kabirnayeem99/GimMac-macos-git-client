import Foundation
import Observation

@MainActor
@Observable
final class DiffHandler {
    private let diffProvider: DiffProviding
    private var diffRequestID: Int = 0
    private var diffCache: [DiffCacheKey: DiffDocument] = [:]

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
        diffRequestID += 1
        selectedFilePath = nil
        selectedDiffDocument = .empty
    }

    func clearCache() {
        diffCache.removeAll()
    }

    func loadDiff(
        in repository: Repository,
        changedFiles: [ChangedFile],
        inspection: RepositoryInspectionResult? = nil
    ) async {
        guard let path = selectedFilePath else {
            selectedDiffDocument = .empty
            return
        }

        diffRequestID += 1
        let requestID = diffRequestID

        let changedFile = changedFiles.first(where: { $0.path == path })
        let cacheKey = Self.cacheKey(repositoryURL: repository.url, path: path, changedFile: changedFile)
        if let cachedDocument = diffCache[cacheKey] {
            selectedDiffDocument = cachedDocument
            isLoadingDiff = false
            return
        }

        if changedFile?.status == .untracked {
            let document = await loadUntrackedFileDiff(repositoryURL: repository.url, path: path)
            guard isCurrentDiffRequest(id: requestID, path: path) else { return }
            selectedDiffDocument = document
            diffCache[cacheKey] = document
            return
        }

        isLoadingDiff = true
        defer {
            if diffRequestID == requestID {
                isLoadingDiff = false
            }
        }

        do {
            if let changedFile, changedFile.submoduleStatus != nil {
                let data = try await diffProvider.submoduleDiff(in: repository.url, for: changedFile)
                guard isCurrentDiffRequest(id: requestID, path: path) else { return }
                let document = DiffDocument(filePath: path, lines: [], kind: .submodule(data))
                selectedDiffDocument = document
                diffCache[cacheKey] = document
                return
            }
            // Pass the rename's old path so the diff shows the move correctly
            // rather than as a brand-new file.
            let diff = try await diffProvider.fetchDiff(
                in: repository.url,
                for: path,
                oldPath: changedFile?.oldPath,
                inspection: inspection
            )
            guard isCurrentDiffRequest(id: requestID, path: path) else { return }
            selectedDiffDocument = diff
            diffCache[cacheKey] = diff
        } catch {
            guard isCurrentDiffRequest(id: requestID, path: path) else { return }
            selectedDiffDocument = DiffDocument(filePath: path, lines: [])
        }
    }

    private func isCurrentDiffRequest(id: Int, path: String) -> Bool {
        diffRequestID == id && selectedFilePath == path
    }

    private static func cacheKey(repositoryURL: URL, path: String, changedFile: ChangedFile?) -> DiffCacheKey {
        let fileURL = repositoryURL.appendingPathComponent(path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modifiedAt = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970
        let fileSize = attributes?[.size] as? Int64

        return DiffCacheKey(
            repositoryPath: repositoryURL.path,
            path: path,
            status: changedFile?.status,
            oldPath: changedFile?.oldPath,
            isStaged: changedFile?.isStaged,
            hasConflict: changedFile?.hasConflict,
            submoduleStatus: changedFile?.submoduleStatus,
            modifiedAt: modifiedAt,
            fileSize: fileSize
        )
    }

    private func loadUntrackedFileDiff(repositoryURL: URL, path: String) async -> DiffDocument {
        let fileURL = repositoryURL.appendingPathComponent(path)
        let content = await Task.detached(priority: .userInitiated) {
            try? String(contentsOf: fileURL, encoding: .utf8)
        }.value

        guard let content else {
            return DiffDocument(filePath: path, lines: [])
        }

        var lines = content.components(separatedBy: .newlines)
        if lines.last == "" {
            lines.removeLast()
        }

        guard !lines.isEmpty else {
            return DiffDocument(filePath: path, lines: [])
        }

        let newRange = lines.count == 1 ? "+1" : "+1,\(lines.count)"
        let header = DiffDocumentLine(
            kind: .hunk,
            oldNumber: nil,
            newNumber: nil,
            text: "@@ -0,0 \(newRange) @@"
        )
        let diffLines = lines.enumerated().map { index, line in
            DiffDocumentLine(kind: .added, oldNumber: nil, newNumber: index + 1, text: line)
        }

        return DiffDocument(filePath: path, lines: [header] + diffLines)
    }
}

private struct DiffCacheKey: Hashable {
    let repositoryPath: String
    let path: String
    let status: GitFileStatus?
    let oldPath: String?
    let isStaged: Bool?
    let hasConflict: Bool?
    let submoduleStatus: SubmoduleStatus?
    let modifiedAt: TimeInterval?
    let fileSize: Int64?
}
