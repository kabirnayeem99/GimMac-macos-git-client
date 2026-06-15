import Foundation

actor GimMacLogger: AppLogging {
    private let maxEntries: Int
    private let fileURL: URL

    init(maxEntries: Int = 2_000, fileURL: URL? = nil) {
        self.maxEntries = maxEntries
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    // MARK: - AppLogging (nonisolated — callers do not need await)

    nonisolated func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let entry = LogEntry(
            kind: .event,
            timestamp: Self.now(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            repositoryPath: nil,
            exitCode: nil,
            stdout: nil,
            stderr: nil,
            error: nil
        )
        print(entry.consoleDescription)
        Task { await self.write(entry) }
    }

    // MARK: - Git command logging (actor-isolated — callers use await)

    func logGitCommand(_ arguments: [String], in repositoryURL: URL, result: GitCommandResult) {
        let entry = LogEntry(
            kind: .git,
            timestamp: Self.now(),
            level: .info,
            category: .git,
            message: "git " + arguments.joined(separator: " "),
            metadata: [:],
            repositoryPath: repositoryURL.path,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            error: nil
        )
        print(entry.consoleDescription)
        write(entry)
    }

    func logGitCommandFailure(_ arguments: [String], in repositoryURL: URL, error: Error) {
        let details = gitErrorDetails(from: error)
        let level: LogLevel = details.exitCode == 1 ? .debug : .error
        let entry = LogEntry(
            kind: .git,
            timestamp: Self.now(),
            level: level,
            category: .git,
            message: "git " + arguments.joined(separator: " "),
            metadata: [:],
            repositoryPath: repositoryURL.path,
            exitCode: details.exitCode,
            stdout: details.stdout,
            stderr: details.stderr,
            error: error.localizedDescription
        )
        print(entry.consoleDescription)
        write(entry)
    }

    // MARK: - Private

    private func write(_ entry: LogEntry) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            var all = (try? read()) ?? []
            all.append(entry)
            if all.count > maxEntries { all = Array(all.suffix(maxEntries)) }
            let encoder = JSONEncoder()
            let lines = try all.map { try String(data: encoder.encode($0), encoding: .utf8) ?? "" }
            try (lines.joined(separator: "\n") + "\n")
                .write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            // Logging must never crash the app
        }
    }

    private func read() throws -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        return try String(contentsOf: fileURL, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> LogEntry? in
                guard let data = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(LogEntry.self, from: data)
            }
    }

    private struct GitErrorDetails {
        let exitCode: Int32?
        let stdout: String
        let stderr: String
    }

    private func gitErrorDetails(from error: Error) -> GitErrorDetails {
        if case .commandFailed(_, let code, let out, let err) = error as? GitAppError {
            return GitErrorDetails(exitCode: code, stdout: out, stderr: err)
        }
        return GitErrorDetails(exitCode: nil, stdout: "", stderr: "")
    }

    private static func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("GimMac", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("gimmac.jsonl", isDirectory: false)
    }
}
