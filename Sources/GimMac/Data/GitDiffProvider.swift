import Foundation

final class GitDiffProvider: DiffProviding, Sendable {
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

        return Self.parseUnifiedDiff(full, path: path)
    }

    func fetchCommitDiff(
        in repositoryURL: URL,
        for path: String,
        commitSHA: String
    ) async throws -> DiffDocument {
        // Try parent..commit first; fall back to `git show` for the root commit.
        let primary = try? await client.run(
            ["diff", "\(commitSHA)^..\(commitSHA)", "--", path],
            in: repositoryURL,
            timeout: 15
        )

        let stdout: String
        if let primary, primary.exitCode == 0,
           !primary.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stdout = primary.stdout
        } else {
            // Initial commit (no parent) — use `git show` which prints a diff against /dev/null.
            let show = try await client.run(
                ["show", "--format=", commitSHA, "--", path],
                in: repositoryURL,
                timeout: 15
            )
            stdout = show.stdout
        }

        return Self.parseUnifiedDiff(stdout, path: path)
    }

    private static func parseUnifiedDiff(_ raw: String, path: String) -> DiffDocument {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return DiffDocument(filePath: path, lines: [])
        }

        let parsedFiles = SwiftyDiffUnifiedParser.parse(raw)
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
