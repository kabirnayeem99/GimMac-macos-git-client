import Foundation

final class GitDiffProvider: DiffProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchDiff(in repositoryURL: URL, for path: String, oldPath: String?) async throws -> DiffDocument {
        // In an unborn repository (no HEAD) every file is effectively new, so a
        // staged-vs-worktree diff would surface a confusing index-vs-worktree
        // delta. Match GitHub Desktop and present the working-tree file as a
        // pure addition.
        if await Self.isUnbornHead(client: client, repositoryURL: repositoryURL) {
            return try await Self.unbornFileDiff(path, client: client, repositoryURL: repositoryURL)
        }

        // Include both the old and new path in the pathspec for a rename so
        // `-M` rename detection can pair them; a single-path scope would hide
        // the old side and render the move as a brand-new file. `-M` is a no-op
        // for non-renamed files.
        let paths: [String]
        if let oldPath, oldPath != path {
            paths = [oldPath, path]
        } else {
            paths = [path]
        }
        let unstaged = try await client.run(["diff", "-M", "--"] + paths, in: repositoryURL, timeout: 10).stdout
        let staged = try await client.run(["diff", "--cached", "-M", "--"] + paths, in: repositoryURL, timeout: 10).stdout

        let full = [unstaged, staged]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        let document = Self.parseUnifiedDiff(full, path: path)

        // A binary change to a recognised image type is presented as an image
        // diff (before/after blobs) rather than an opaque binary marker.
        if document.isBinary, Self.isImagePath(path) {
            let previous = try? await blobImage(in: repositoryURL, for: path, at: "HEAD")
            let current = try? await workingDirectoryImage(in: repositoryURL, for: path)
            return DiffDocument(
                filePath: path,
                lines: [],
                kind: .image(ImageDiffData(previous: previous, current: current))
            )
        }
        return document
    }

    // MARK: - Submodule

    func submoduleDiff(in repositoryURL: URL, for changedFile: ChangedFile) async throws -> SubmoduleDiffData {
        let status = changedFile.submoduleStatus
        let commitChanged = status?.commitChanged ?? false

        var oldSHA: String?
        var newSHA: String?
        if commitChanged {
            // Gitlink SHAs are only meaningful when the recorded commit moved.
            let raw = try await client.run(
                ["diff", "--submodule=short", "--", changedFile.path],
                in: repositoryURL,
                timeout: 10
            ).stdout
            (oldSHA, newSHA) = Self.parseSubprojectSHAs(raw)
        }

        return SubmoduleDiffData(
            path: changedFile.path,
            fullPath: repositoryURL.appendingPathComponent(changedFile.path).path,
            oldSHA: oldSHA,
            newSHA: newSHA,
            commitChanged: commitChanged,
            modifiedChanges: status?.modifiedChanges ?? false,
            untrackedChanges: status?.untrackedChanges ?? false
        )
    }

    /// Extracts the old/new gitlink SHAs from the `-/+Subproject commit <sha>`
    /// lines, stripping any `-dirty` suffix.
    private static func parseSubprojectSHAs(_ raw: String) -> (String?, String?) {
        var old: String?
        var new: String?
        for line in raw.components(separatedBy: "\n") {
            if line.hasPrefix("-Subproject commit ") {
                old = cleanSubprojectSHA(line.dropFirst("-Subproject commit ".count))
            } else if line.hasPrefix("+Subproject commit ") {
                new = cleanSubprojectSHA(line.dropFirst("+Subproject commit ".count))
            }
        }
        return (old, new)
    }

    private static func cleanSubprojectSHA(_ value: Substring) -> String {
        var sha = value.trimmingCharacters(in: .whitespaces)
        if sha.hasSuffix("-dirty") { sha = String(sha.dropLast("-dirty".count)) }
        return sha
    }

    // MARK: - Image

    func workingDirectoryImage(in repositoryURL: URL, for path: String) async throws -> ImageDiffContent {
        let data = try Data(contentsOf: repositoryURL.appendingPathComponent(path))
        return ImageDiffContent(mediaType: Self.mediaType(for: path), base64Contents: data.base64EncodedString())
    }

    func blobImage(in repositoryURL: URL, for path: String, at ref: String) async throws -> ImageDiffContent {
        let data = try await client.runReturningData(["show", "\(ref):\(path)"], in: repositoryURL, timeout: 10)
        return ImageDiffContent(mediaType: Self.mediaType(for: path), base64Contents: data.base64EncodedString())
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "ico", "webp", "bmp", "svg", "avif"]

    private static func isImagePath(_ path: String) -> Bool {
        imageExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    /// Media type by extension. Mirrors GitHub Desktop's mapping (note `jpg`/`jpeg`
    /// both report `image/jpg`).
    private static func mediaType(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpg"
        case "gif": return "image/gif"
        case "ico": return "image/x-icon"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "svg": return "image/svg+xml"
        case "avif": return "image/avif"
        default: return "application/octet-stream"
        }
    }

    /// `true` when the repository has no commits yet (`HEAD` cannot be resolved).
    private static func isUnbornHead(client: GitClientProtocol, repositoryURL: URL) async -> Bool {
        // `rev-parse --verify HEAD` exits non-zero (and `run` throws) in an
        // unborn repository.
        let result = try? await client.run(["rev-parse", "--verify", "HEAD"], in: repositoryURL, timeout: 5)
        return result == nil
    }

    /// The working-tree contents of `path` rendered as a pure addition, for use
    /// when there is no HEAD to diff against.
    private static func unbornFileDiff(
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

    /// `git` reports binary changes as a one-line summary instead of hunks.
    private static func isBinaryDiff(_ raw: String) -> Bool {
        raw.contains("Binary files ") || raw.contains("GIT binary patch")
    }

    private static func parseUnifiedDiff(_ raw: String, path: String) -> DiffDocument {
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
