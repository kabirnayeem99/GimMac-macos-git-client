import Foundation

struct GitCommandLogEntry: Codable, Sendable {
    let timestamp: String
    let repositoryPath: String
    let command: String
    let arguments: [String]
    let exitCode: Int32?
    let stdout: String
    let stderr: String
    let error: String?
}

actor GitCommandLogger {
    private let maxEntries: Int
    private let fileURL: URL

    init(maxEntries: Int = 1_000) {
        self.maxEntries = maxEntries
        self.fileURL = Self.makeLogFileURL()
    }

    func logSuccess(arguments: [String], repositoryURL: URL, result: GitCommandResult) async {
        let entry = GitCommandLogEntry(
            timestamp: Self.timestampString(for: Date()),
            repositoryPath: repositoryURL.path,
            command: "git \(arguments.joined(separator: " "))",
            arguments: arguments,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            error: nil
        )
        await append(entry)
    }

    func logFailure(arguments: [String], repositoryURL: URL, error: Error) async {
        let entry: GitCommandLogEntry

        switch error {
        case let gitError as GitAppError:
            switch gitError {
            case .commandFailed(_, let exitCode, let stdout, let stderr):
                entry = GitCommandLogEntry(
                    timestamp: Self.timestampString(for: Date()),
                    repositoryPath: repositoryURL.path,
                    command: "git \(arguments.joined(separator: " "))",
                    arguments: arguments,
                    exitCode: exitCode,
                    stdout: stdout,
                    stderr: stderr,
                    error: gitError.localizedDescription
                )
            default:
                entry = GitCommandLogEntry(
                    timestamp: Self.timestampString(for: Date()),
                    repositoryPath: repositoryURL.path,
                    command: "git \(arguments.joined(separator: " "))",
                    arguments: arguments,
                    exitCode: nil,
                    stdout: "",
                    stderr: "",
                    error: gitError.localizedDescription
                )
            }
        default:
            entry = GitCommandLogEntry(
                timestamp: Self.timestampString(for: Date()),
                repositoryPath: repositoryURL.path,
                command: "git \(arguments.joined(separator: " "))",
                arguments: arguments,
                exitCode: nil,
                stdout: "",
                stderr: "",
                error: error.localizedDescription
            )
        }

        await append(entry)
    }

    private func append(_ entry: GitCommandLogEntry) async {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            var entries = try readEntries()
            entries.append(entry)
            if entries.count > maxEntries {
                entries = Array(entries.suffix(maxEntries))
            }

            let encoder = JSONEncoder()
            let lines = try entries.map { entry -> String in
                let data = try encoder.encode(entry)
                return String(decoding: data, as: UTF8.self)
            }

            let serialized = lines.joined(separator: "\n") + "\n"
            try serialized.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            // Logging must never interrupt Git operations.
        }
    }

    private func readEntries() throws -> [GitCommandLogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        return lines.compactMap { line in
            guard let data = line.data(using: .utf8) else {
                return nil
            }
            return try? decoder.decode(GitCommandLogEntry.self, from: data)
        }
    }

    private static func timestampString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func makeLogFileURL() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseDirectory
            .appendingPathComponent("GimMac", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("git-commands.jsonl", isDirectory: false)
    }
}
