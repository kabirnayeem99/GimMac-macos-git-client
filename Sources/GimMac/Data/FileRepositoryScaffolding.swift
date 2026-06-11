import Foundation

/// Writes scaffold files into a freshly-initialised repository using plain
/// Foundation file writes — no git command is run. Native equivalent of GitHub
/// Desktop's `writeDefaultReadme` / `writeGitIgnore` / `writeGitAttributes` /
/// `writeLicense` / `writeGitDescription`.
///
/// All writes are atomic and UTF-8. Failures are mapped to
/// `GitAppError.scaffoldingFailed` so they surface with the offending filename.
final class FileRepositoryScaffolding: RepositoryScaffolding, Sendable {
    init() {}

    func writeReadme(name: String, description: String?, in directoryURL: URL) async throws {
        // GitHub Desktop's `defaultReadmeContents`: `# {name}\n{description}\n`
        // when a description is present, `# {name}\n` otherwise.
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contents: String
        if let trimmedDescription, !trimmedDescription.isEmpty {
            contents = "# \(name)\n\(trimmedDescription)\n"
        } else {
            contents = "# \(name)\n"
        }
        try write(contents, to: directoryURL.appendingPathComponent("README.md"), file: "README.md")
    }

    func writeGitIgnore(contents: String, in directoryURL: URL) async throws {
        try write(contents, to: directoryURL.appendingPathComponent(".gitignore"), file: ".gitignore")
    }

    func writeGitAttributes(in directoryURL: URL) async throws {
        // Exact match to GitHub Desktop's `writeGitAttributes`.
        let contents = "# Auto detect text files and perform LF normalization\n* text=auto\n"
        try write(contents, to: directoryURL.appendingPathComponent(".gitattributes"), file: ".gitattributes")
    }

    func writeLicense(_ license: LicenseTemplate, fields: LicenseFields, in directoryURL: URL) async throws {
        let body = Self.substituteTokens(in: license.body, fields: fields)
        try write(body, to: directoryURL.appendingPathComponent("LICENSE"), file: "LICENSE")
    }

    func writeGitDescription(_ description: String, in directoryURL: URL) async throws {
        let descriptionURL = directoryURL
            .appendingPathComponent(".git")
            .appendingPathComponent("description")
        try write(description, to: descriptionURL, file: ".git/description")
    }

    // MARK: - Token substitution

    /// License templates use inconsistent placeholder styles — `[token]` in some,
    /// `{token}` in others. Normalise `[token]` to `{token}`, then substitute.
    /// Mirrors GitHub Desktop's `replaceToken` / `replaceTokens`.
    static func substituteTokens(in body: String, fields: LicenseFields) -> String {
        let replacements: [(token: String, value: String)] = [
            ("fullname", fields.fullname),
            ("email", fields.email),
            ("project", fields.project),
            ("year", fields.year),
        ]
        var result = body
        for (token, value) in replacements {
            result = result
                .replacingOccurrences(of: "[\(token)]", with: "{\(token)}")
                .replacingOccurrences(of: "{\(token)}", with: value)
        }
        return result
    }

    // MARK: - Write helper

    private func write(_ contents: String, to url: URL, file: String) throws {
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw GitAppError.scaffoldingFailed(file: file, reason: error.localizedDescription)
        }
    }
}
