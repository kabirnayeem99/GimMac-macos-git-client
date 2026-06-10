import Foundation

final class GitHistoryProvider: HistoryProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchHistory(in repositoryURL: URL, maxCount: Int?) async throws -> [Commit] {
        var arguments = ["log", "--format=\(GitLogParser.logFormat)"]
        if let maxCount = maxCount {
            arguments.append("-n")
            arguments.append("\(maxCount)")
        }

        let result = try await client.run(arguments, in: repositoryURL, timeout: 15)
        return GitLogParser.parse(result.stdout)
    }
}

final class GitStatusProvider: StatusProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchStatus(in repositoryURL: URL) async throws -> [ChangedFile] {
        let arguments = ["status", "--porcelain=v1", "-uall"]
        let result = try await client.run(arguments, in: repositoryURL, timeout: 10)
        return GitStatusParser.parse(result.stdout)
    }
}

final class GitCommitProvider: CommitProviding, Sendable {
    private let client: GitClientProtocol
    private let logger: any AppLogging

    init(client: GitClientProtocol, logger: any AppLogging) {
        self.client = client
        self.logger = logger
    }

    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?,
        options: CommitOptions
    ) async throws {
        let normalizedPaths = Array(Set(paths)).sorted()
        guard options.isAmend || !normalizedPaths.isEmpty else { return }

        logger.info(
            "Staging \(normalizedPaths.count) file(s)",
            category: .staging,
            metadata: ["repository": repositoryURL.lastPathComponent, "amend": "\(options.isAmend)"]
        )

        var stagedPaths: [String] = []
        for path in normalizedPaths {
            do {
                _ = try await client.run(["add", "-A", "--", path], in: repositoryURL, timeout: 15)
                stagedPaths.append(path)
                logger.debug("Staged", category: .staging, metadata: ["path": path])
            } catch {
                logger.warning(
                    "Skipping unstage-able path",
                    category: .staging,
                    metadata: ["path": path, "reason": error.localizedDescription]
                )
            }
        }

        logger.info(
            "Staged \(stagedPaths.count) of \(normalizedPaths.count) file(s)",
            category: .staging,
            metadata: ["files": stagedPaths.joined(separator: ", ")]
        )

        var args = ["commit", "-m", summary]
        if let description, !description.isEmpty { args += ["-m", description] }
        // Co-authors as a trailing `-m` paragraph. Git keeps each `-m` as its own
        // paragraph (blank-line separated); the trailer lines land in the final
        // paragraph, which is the trailer block git recognises.
        if !options.coAuthors.isEmpty {
            let trailer = options.coAuthors.map(\.trailerLine).joined(separator: "\n")
            args += ["-m", trailer]
        }
        if options.isAmend { args.append("--amend") }
        if options.skipHooks { args.append("--no-verify") }
        if options.signOff { args.append("--signoff") }

        _ = try await client.run(args, in: repositoryURL, timeout: 20)
    }

    func undoLastCommit(in repositoryURL: URL) async throws {
        _ = try await client.run(["reset", "--soft", "HEAD~1"], in: repositoryURL, timeout: 15)
    }
}

final class GitCommitInspector: CommitInspecting, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchFiles(for commitSHA: String, in repositoryURL: URL) async throws -> [CommitFile] {
        // -m expands merge commits to show a diff per parent (instead of a combined diff
        // that is empty for clean merges). --root handles the initial commit (no parent).
        let arguments = ["diff-tree", "--no-commit-id", "-r", "--name-status", "--root", "-m", commitSHA]
        let result = try await client.run(arguments, in: repositoryURL, timeout: 10)
        return Self.parse(result.stdout)
    }

    static func parse(_ output: String) -> [CommitFile] {
        let lines = output.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" })
        var files: [CommitFile] = []
        var seen = Set<String>()
        files.reserveCapacity(lines.count)
        for raw in lines {
            let trimmed = String(raw).trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }

            // Rename/copy lines have form: R100\tOLD\tNEW (or C100\tOLD\tNEW).
            // For these we use the new path as the file path and status .renamed.
            let statusToken = parts[0]
            let statusLetter = statusToken.first.map(String.init) ?? ""
            let status = GitFileStatus(rawValue: statusLetter) ?? .unknown

            let path: String
            if statusLetter == "R" || statusLetter == "C", parts.count >= 3 {
                path = parts[2]
            } else {
                path = parts[1]
            }
            // -m can produce the same path from multiple parent diffs; keep first occurrence.
            guard seen.insert(path).inserted else { continue }
            files.append(CommitFile(path: path, status: status))
        }
        return files
    }
}

final class GitDiscardProvider: DiscardProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func discardChanges(in repositoryURL: URL, for path: String, status: GitFileStatus) async throws {
        let arguments: [String]
        switch status {
        case .untracked, .ignored:
            arguments = ["clean", "-f", "--", path]
        default:
            arguments = ["checkout", "HEAD", "--", path]
        }
        _ = try await client.run(arguments, in: repositoryURL, timeout: 15)
    }

    func discardAllChanges(in repositoryURL: URL) async throws {
        // Revert tracked changes (staged + unstaged), then remove untracked
        // files and directories. Two steps because `reset --hard` leaves
        // untracked files in place.
        _ = try await client.run(["reset", "--hard", "HEAD"], in: repositoryURL, timeout: 30)
        _ = try await client.run(["clean", "-fd"], in: repositoryURL, timeout: 30)
    }
}

final class GitStashProvider: StashProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func fetchStash(in repositoryURL: URL) async throws -> StashEntry? {
        let format = "%gd%x00%s%x00%gD"
        let result = try await client.run(
            ["stash", "list", "-n", "1", "--format=\(format)"],
            in: repositoryURL,
            timeout: 10
        )
        let line = result.stdout.split(separator: "\n").first.map(String.init) ?? ""
        guard !line.isEmpty else { return nil }
        let parts = line.components(separatedBy: "\0")
        guard parts.count >= 2 else { return nil }
        let id = parts[0]
        let message = parts[1]
        // Try to parse "WIP on <branch>: ..." from the message
        let branchName = Self.parseBranchName(from: message) ?? ""
        return StashEntry(id: id, message: message, branchName: branchName)
    }

    func applyStash(in repositoryURL: URL) async throws {
        _ = try await client.run(["stash", "pop"], in: repositoryURL, timeout: 30)
    }

    func dropStash(in repositoryURL: URL) async throws {
        _ = try await client.run(["stash", "drop"], in: repositoryURL, timeout: 10)
    }

    func pushStash(in repositoryURL: URL, message: String?) async throws {
        var arguments = ["stash", "push", "--include-untracked"]
        if let message, !message.isEmpty {
            arguments += ["-m", message]
        }
        _ = try await client.run(arguments, in: repositoryURL, timeout: 30)
    }

    private static func parseBranchName(from message: String) -> String? {
        // "WIP on branch: ..." or "On branch: ..."
        let scanners = ["WIP on ", "On "]
        for prefix in scanners where message.hasPrefix(prefix) {
            let rest = message.dropFirst(prefix.count)
            if let colon = rest.firstIndex(of: ":") {
                return String(rest[..<colon])
            }
        }
        return nil
    }
}

// MARK: - Squash

final class GitSquashProvider: SquashProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func squash(commits: [Commit], message: String, in repositoryURL: URL) async throws {
        guard commits.count >= 2 else { return }

        // commits is newest-first. The oldest commit is the squashOnto (gets `pick`).
        // All other selected commits get `squash`.
        let squashOnto = commits.last!
        let toSquashIDs = Set(commits.dropLast().map(\.id))

        // Find the parent of squashOnto — this is the rebase base.
        let parentResult = try await client.run(
            ["log", "--format=%P", "-n", "1", squashOnto.id],
            in: repositoryURL,
            timeout: 10
        )
        let parentSHA = parentResult.stdout
            .components(separatedBy: .whitespacesAndNewlines)
            .first { !$0.isEmpty } ?? ""

        // Fetch ALL commits in the rebase range, oldest→newest.
        // Without this, an `--root` rebase would drop every commit not in the todo.
        let logArgs: [String] = parentSHA.isEmpty
            ? ["log", "--format=%H%x00%s", "--reverse", "HEAD"]
            : ["log", "--format=%H%x00%s", "--reverse", "\(parentSHA)..HEAD"]
        let rangeResult = try await client.run(logArgs, in: repositoryURL, timeout: 15)

        // Build the full todo: unselected commits keep `pick`, toSquash commits get `squash`.
        // squashOnto is not in toSquashIDs, so it also gets `pick`.
        var todoLines: [String] = []
        for rawLine in rangeResult.stdout.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" }) {
            let line = String(rawLine)
            guard !line.isEmpty else { continue }
            let parts = line.components(separatedBy: "\0")
            let sha = parts[0]
            let summary = (parts.count > 1 ? parts[1] : "")
                .replacingOccurrences(of: "\n", with: " ")
            let action = toSquashIDs.contains(sha) ? "squash" : "pick"
            todoLines.append("\(action) \(sha) \(summary)")
        }
        let todoContent = todoLines.joined(separator: "\n") + "\n"

        let tempDir = FileManager.default.temporaryDirectory
        let runID = UUID().uuidString
        let todoURL = tempDir.appendingPathComponent("gimmac-squash-todo-\(runID)")
        let messageURL = tempDir.appendingPathComponent("gimmac-squash-msg-\(runID)")

        defer {
            try? FileManager.default.removeItem(at: todoURL)
            try? FileManager.default.removeItem(at: messageURL)
        }

        try todoContent.write(to: todoURL, atomically: true, encoding: .utf8)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        try trimmedMessage.write(to: messageURL, atomically: true, encoding: .utf8)

        let todoPath = todoURL.path
        let messagePath = messageURL.path

        // GIT_SEQUENCE_EDITOR: copies our todo over git's rebase-todo file.
        // GIT_EDITOR: copies our message over git's squash-commit-message file.
        // Both work because git invokes them via `sh -c`, so the `>` redirect is honored.
        let extraEnv: [String: String] = [
            "GIT_SEQUENCE_EDITOR": "cat \"\(todoPath)\" >",
            "GIT_EDITOR": "cat \"\(messagePath)\" >",
            "GIT_TERMINAL_PROMPT": "0"
        ]

        let rebaseArgs: [String] = parentSHA.isEmpty
            ? ["rebase", "-i", "--root"]
            : ["rebase", "-i", parentSHA]

        _ = try await client.run(rebaseArgs, in: repositoryURL, extraEnvironment: extraEnv, timeout: 120)
    }
}

// MARK: - Revert

final class GitRevertProvider: RevertProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func revert(commit: Commit, in repositoryURL: URL) async throws {
        do {
            _ = try await client.run(["revert", "--no-edit", commit.id], in: repositoryURL, timeout: 60)
        } catch {
            // Conflict or failure leaves the repo mid-revert. Abort so the
            // working tree returns to a clean state, then surface the error.
            _ = try? await client.run(["revert", "--abort"], in: repositoryURL, timeout: 15)
            throw error
        }
    }
}

// MARK: - Cherry-pick

final class GitCherryPickProvider: CherryPickProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func cherryPick(commits: [Commit], in repositoryURL: URL) async throws {
        guard !commits.isEmpty else { return }

        // commits is newest-first; cherry-pick applies arguments left→right, so
        // reverse to oldest-first to preserve original commit order on HEAD.
        let shas = commits.reversed().map(\.id)
        do {
            _ = try await client.run(["cherry-pick"] + shas, in: repositoryURL, timeout: 120)
        } catch {
            // Conflict or failure leaves the repo mid-cherry-pick. Abort so the
            // working tree returns to a clean state, then surface the error.
            _ = try? await client.run(["cherry-pick", "--abort"], in: repositoryURL, timeout: 15)
            throw error
        }
    }
}

// MARK: - Tag

final class GitTagProvider: TagProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func createTag(named name: String, message: String?, at commit: Commit, in repositoryURL: URL) async throws {
        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let arguments: [String] = trimmedMessage.isEmpty
            ? ["tag", name, commit.id]
            : ["tag", "-a", name, "-m", trimmedMessage, commit.id]
        _ = try await client.run(arguments, in: repositoryURL, timeout: 15)
    }
}
