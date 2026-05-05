import Foundation

final class GitDiffProvider: DiffProviding, @unchecked Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchDiff(in repositoryURL: URL, for path: String) async throws -> DiffDocument {
        let unstaged = try await client.run(["diff", "--", path], in: repositoryURL, timeout: 10).stdout
        let staged = try await client.run(["diff", "--cached", "--", path], in: repositoryURL, timeout: 10).stdout

        let full = [unstaged, staged]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        guard !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return DiffDocument(filePath: path, lines: [])
        }

        let parsedFiles = SwiftyDiffUnifiedParser.parse(full)
        let parsedFile = parsedFiles.first { $0.path == path } ?? parsedFiles.first

        guard let parsedFile else {
            return DiffDocument(filePath: path, lines: [])
        }

        let lines = parsedFile.hunks.flatMap { hunk in
            hunk.lines.map { parsed in
                let kind: DiffDocumentLineKind
                switch parsed.type {
                case .context:
                    kind = .context
                case .addition:
                    kind = .added
                case .deletion:
                    kind = .removed
                }

                return DiffDocumentLine(
                    kind: kind,
                    oldNumber: parsed.oldLineNumber,
                    newNumber: parsed.newLineNumber,
                    text: parsed.content
                )
            }
        }

        return DiffDocument(filePath: parsedFile.path, lines: lines)
    }
}
