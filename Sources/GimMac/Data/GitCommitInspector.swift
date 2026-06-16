import Foundation

/// Inspects an arbitrary commit and returns the files that changed in it.
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
