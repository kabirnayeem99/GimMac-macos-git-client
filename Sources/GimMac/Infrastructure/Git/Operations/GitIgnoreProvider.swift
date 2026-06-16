import Foundation

/// Appends rules to the repository root `.gitignore`. Native equivalent of
/// GitHub Desktop's `appendIgnoreFile` / `appendIgnoreRule` (`gitignore.ts`).
///
/// This is a plain file write — no git command is run. The file is always the
/// repository root `.gitignore`; rules are de-duplicated against existing lines
/// and appended with a `\n` separator, preserving any trailing newline.
final class GitIgnoreProvider: GitIgnoreProviding, Sendable {
    init() {}

    func appendIgnoreEntries(_ entries: [String], in repositoryURL: URL) async throws {
        let cleaned = entries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }

        let gitignoreURL = repositoryURL.appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOf: gitignoreURL, encoding: .utf8)) ?? ""

        // De-dupe against existing rules (compare trimmed lines).
        let existingRules = Set(
            existing
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        )
        let newRules = cleaned.filter { !existingRules.contains($0) }
        guard !newRules.isEmpty else { return }

        var output = existing
        if !output.isEmpty && !output.hasSuffix("\n") { output += "\n" }
        output += newRules.joined(separator: "\n") + "\n"

        try output.write(to: gitignoreURL, atomically: true, encoding: .utf8)
    }
}
