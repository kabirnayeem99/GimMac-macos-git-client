import Foundation

/// Reorders a contiguous set of commits by rewriting the interactive rebase todo.
final class GitReorderProvider: ReorderProviding, Sendable {
    private let client: GitClientProtocol

    init(client: GitClientProtocol) {
        self.client = client
    }

    func reorder(orderedCommits: [Commit], in repositoryURL: URL) async throws {
        guard orderedCommits.count >= 2 else { return }

        let selectedIDs = Set(orderedCommits.map(\.id))

        // Full history oldest→newest. We locate the earliest selected commit to
        // anchor the rebase; everything before it is left untouched.
        let logResult = try await client.run(
            ["log", "--format=%H%x00%s", "--reverse", "HEAD"],
            in: repositoryURL,
            timeout: 15
        )

        var rangeShas: [String] = []
        var summaryBySha: [String: String] = [:]
        for rawLine in logResult.stdout.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" }) {
            let line = String(rawLine)
            guard !line.isEmpty else { continue }
            let parts = line.components(separatedBy: "\0")
            let sha = parts[0]
            let summary = (parts.count > 1 ? parts[1] : "").replacingOccurrences(of: "\n", with: " ")
            summaryBySha[sha] = summary
            rangeShas.append(sha)
        }

        guard let firstSelectedIndex = rangeShas.firstIndex(where: { selectedIDs.contains($0) }) else {
            return
        }

        // Rebase base is the parent of the earliest selected commit, or --root
        // when that commit is the repository's first commit.
        let parentSHA: String? = firstSelectedIndex == 0 ? nil : rangeShas[firstSelectedIndex - 1]
        let todoShas = Array(rangeShas[firstSelectedIndex...])

        // Desired order of the selected commits, oldest→newest (UI lists them
        // newest-first). Consumed in order as we reach each selected slot.
        let desiredQueue = orderedCommits.reversed().map(\.id)
        var desiredIndex = 0

        var todoLines: [String] = []
        for sha in todoShas {
            let emittedSha: String
            if selectedIDs.contains(sha) {
                emittedSha = desiredQueue[desiredIndex]
                desiredIndex += 1
            } else {
                emittedSha = sha
            }
            let summary = summaryBySha[emittedSha] ?? ""
            todoLines.append("pick \(emittedSha) \(summary)")
        }
        let todoContent = todoLines.joined(separator: "\n") + "\n"

        // Controlled wrapper script (payload path shell-escaped) instead of
        // interpolating the temp path into a shell-parsed editor command.
        let todoEditor = try GitEditorScript.make(payload: todoContent, label: "reorder-todo")
        defer { todoEditor.cleanup() }

        let extraEnv: [String: String] = [
            "GIT_SEQUENCE_EDITOR": todoEditor.editorCommand,
            "GIT_TERMINAL_PROMPT": "0"
        ]
        let rebaseArgs: [String]
        if let parentSHA {
            rebaseArgs = ["rebase", "-i", parentSHA]
        } else {
            rebaseArgs = ["rebase", "-i", "--root"]
        }

        do {
            _ = try await client.run(rebaseArgs, in: repositoryURL, extraEnvironment: extraEnv, timeout: 120)
        } catch {
            // Conflict or failure leaves the repo mid-rebase. Abort so the
            // working tree returns to a clean state, then surface the error.
            _ = try? await client.run(["rebase", "--abort"], in: repositoryURL, timeout: 15)
            throw error
        }
    }
}
