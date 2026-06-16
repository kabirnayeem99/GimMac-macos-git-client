import Foundation

/// Produces diff documents for working-tree and commit changes. Delegates binary
/// image handling, submodule handling, and unified-diff parsing to focused extensions.
final class GitDiffProvider: DiffProviding, Sendable {
    internal let client: GitClientProtocol

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
            // Both sides nil means the image was oversized or unreadable; fall
            // back to the binary marker rather than an empty image diff.
            guard previous != nil || current != nil else { return document }
            return DiffDocument(
                filePath: path,
                lines: [],
                kind: .image(ImageDiffData(previous: previous, current: current))
            )
        }
        return document
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
}
