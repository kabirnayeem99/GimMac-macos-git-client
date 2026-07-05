import Foundation

/// Squashes a contiguous range of commits by rewriting the rebase todo list.
final class GitSquashProvider: SquashProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func squash(commits: [Commit], message: String, in repositoryURL: URL) async throws {
        guard commits.count >= 2 else { return }

        // commits is newest-first. The oldest commit is the squashOnto (gets `pick`).
        // All other selected commits get `squash`.
        guard let squashOnto = commits.last else { return }
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
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // GIT_SEQUENCE_EDITOR copies our todo over git's rebase-todo file;
        // GIT_EDITOR copies our message over git's squash-commit-message file.
        // Each is a controlled wrapper script (paths are shell-escaped) so a
        // temp path containing shell metacharacters cannot mis-parse or execute.
        let todoEditor = try GitEditorScript.make(payload: todoContent, label: "squash-todo")
        let messageEditor = try GitEditorScript.make(payload: trimmedMessage, label: "squash-msg")
        defer {
            todoEditor.cleanup()
            messageEditor.cleanup()
        }

        let extraEnv: [String: String] = [
            "GIT_SEQUENCE_EDITOR": todoEditor.editorCommand,
            "GIT_EDITOR": messageEditor.editorCommand,
            "GIT_TERMINAL_PROMPT": "0"
        ]

        let rebaseArgs: [String] = parentSHA.isEmpty
            ? ["rebase", "-i", "--root"]
            : ["rebase", "-i", parentSHA]

        do {
            _ = try await client.run(rebaseArgs, in: repositoryURL, extraEnvironment: extraEnv, timeout: 120)
        } catch {
            _ = try? await client.run(["rebase", "--abort"], in: repositoryURL, timeout: 15)
            throw error
        }
    }
}
