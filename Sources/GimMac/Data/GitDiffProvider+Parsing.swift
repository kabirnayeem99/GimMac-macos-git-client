import Foundation

extension GitDiffProvider {
    /// `true` only when the repository genuinely has no commits yet. A bare
    /// `result == nil` check would also fire on timeouts, permission errors, or a
    /// corrupt repository, causing the caller to mis-render a tracked file as a
    /// pure addition. Detect the missing-HEAD stderr specifically; any other
    /// failure is treated as "not unborn" so the normal diff path runs.
    internal static func isUnbornHead(client: GitClientProtocol, repositoryURL: URL) async -> Bool {
        do {
            _ = try await client.run(["rev-parse", "--verify", "HEAD"], in: repositoryURL, timeout: 5)
            return false
        } catch let GitAppError.commandFailed(_, _, _, stderr) {
            let normalized = stderr.lowercased()
            return normalized.contains("unknown revision")
                || normalized.contains("needed a single revision")
                || normalized.contains("ambiguous argument 'head'")
        } catch {
            return false
        }
    }

    /// The working-tree contents of `path` rendered as a pure addition, for use
    /// when there is no HEAD to diff against.
    internal static func unbornFileDiff(
        _ path: String,
        client: GitClientProtocol,
        repositoryURL: URL
    ) async throws -> DiffDocument {
        let stdout: String
        do {
            stdout = try await client.run(
                ["diff", "--no-index", "--", "/dev/null", path],
                in: repositoryURL,
                timeout: 10
            ).stdout
        } catch let error as GitAppError {
            // `git diff --no-index` exits 1 when the files differ; the unified
            // diff is on stdout. Any other failure propagates.
            guard case let .commandFailed(_, _, out, _) = error, !out.isEmpty else { throw error }
            stdout = out
        }
        return parseUnifiedDiff(stdout, path: path)
    }

    /// `git` reports binary changes as a one-line summary instead of hunks.
    internal static func isBinaryDiff(_ raw: String) -> Bool {
        raw.contains("Binary files ") || raw.contains("GIT binary patch")
    }

    internal static func parseUnifiedDiff(_ raw: String, path: String) -> DiffDocument {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return DiffDocument(filePath: path, lines: [])
        }

        if isBinaryDiff(raw) {
            return DiffDocument(filePath: path, lines: [], kind: .binary)
        }

        let parsedFiles = SwiftyDiffUnifiedParser.parse(raw)
        let parsedFile = parsedFiles.first { $0.path == path } ?? parsedFiles.first

        guard let parsedFile else {
            return DiffDocument(filePath: path, lines: [])
        }

        let lines = parsedFile.hunks.flatMap { hunk -> [DiffDocumentLine] in
            let header = DiffDocumentLine(
                kind: .hunk,
                oldNumber: nil,
                newNumber: nil,
                text: hunk.header
            )
            let content = hunk.lines.map { parsed in
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
            return [header] + content
        }

        return DiffDocument(filePath: parsedFile.path, lines: lines)
    }
}
