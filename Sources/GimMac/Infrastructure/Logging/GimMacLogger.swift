import Foundation

actor GimMacLogger: AppLogging {
    struct Configuration: Sendable {
        var isEnabled: Bool
        var writesToConsole: Bool
        var maxEntries: Int
        var rotationInterval: Int

        static var `default`: Configuration {
            #if DEBUG
            return Configuration(isEnabled: true, writesToConsole: true, maxEntries: 2_000, rotationInterval: 250)
            #else
            return Configuration(isEnabled: false, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
            #endif
        }
    }

    struct GitCommandStartContext: Sendable {
        let arguments: [String]
        let repositoryURL: URL
        let commandID: UUID
        let timeout: TimeInterval
        let extraEnvironment: [String: String]
    }

    nonisolated private let writer: BackgroundLogWriter
    nonisolated private let appStartUptime: TimeInterval

    init(maxEntries: Int? = nil, fileURL: URL? = nil, configuration: Configuration = .default) {
        var effectiveConfiguration = configuration
        if let maxEntries {
            effectiveConfiguration.maxEntries = maxEntries
        }
        self.writer = BackgroundLogWriter(
            fileURL: fileURL ?? Self.defaultFileURL(),
            configuration: effectiveConfiguration
        )
        self.appStartUptime = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - AppLogging

    nonisolated func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String] = [:]
    ) {
        log(level: level, category: category, message: message, metadata: metadata, tag: nil)
    }

    nonisolated func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String],
        tag: LogFlowTag?
    ) {
        writer.enqueue(
            .event(level: level, category: category, message: message, metadata: metadata, tag: tag),
            appStartUptime: appStartUptime
        )
    }

    nonisolated func tag(_ name: String, parent: LogFlowTag? = nil, metadata: [String: String] = [:]) -> LogFlowTag {
        LogFlowTag(
            name: name,
            parent: parent,
            metadata: metadata,
            runtimeMilliseconds: Self.runtimeMilliseconds(since: appStartUptime)
        )
    }

    nonisolated func flush() async {
        await withCheckedContinuation { continuation in
            writer.flush {
                continuation.resume()
            }
        }
    }

    // MARK: - Git command logging

    func logGitCommandStarted(_ context: GitCommandStartContext, tag: LogFlowTag?) {
        writer.enqueue(
            .git(
                arguments: context.arguments,
                repositoryPath: context.repositoryURL.path,
                level: .debug,
                exitCode: nil,
                stdout: "",
                stderr: "",
                error: nil,
                metadata: [
                    "git.command_id": context.commandID.uuidString,
                    "git.phase": "started",
                    "git.timeout_seconds": String(context.timeout),
                    "git.extra_environment_keys": context.extraEnvironment.keys.sorted().joined(separator: ",")
                ],
                tag: tag
            ),
            appStartUptime: appStartUptime
        )
    }

    func logGitCommand(
        _ arguments: [String],
        in repositoryURL: URL,
        result: GitCommandResult,
        durationMilliseconds: Double? = nil,
        commandID: UUID? = nil,
        tag: LogFlowTag? = nil
    ) {
        var metadata: [String: String] = ["git.phase": "completed"]
        if let durationMilliseconds {
            metadata["git.duration_ms"] = Self.formatMilliseconds(durationMilliseconds)
        }
        if let commandID {
            metadata["git.command_id"] = commandID.uuidString
        }

        writer.enqueue(
            .git(
                arguments: arguments,
                repositoryPath: repositoryURL.path,
                level: .info,
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr,
                error: nil,
                metadata: metadata,
                tag: tag
            ),
            appStartUptime: appStartUptime
        )
    }

    func logGitCommandFailure(
        _ arguments: [String],
        in repositoryURL: URL,
        error: Error,
        durationMilliseconds: Double? = nil,
        commandID: UUID? = nil,
        tag: LogFlowTag? = nil
    ) {
        let details = gitErrorDetails(from: error)
        let level: LogLevel = details.exitCode == 1 ? .debug : .error
        var metadata: [String: String] = ["git.phase": "failed"]
        if let durationMilliseconds {
            metadata["git.duration_ms"] = Self.formatMilliseconds(durationMilliseconds)
        }
        if let commandID {
            metadata["git.command_id"] = commandID.uuidString
        }

        writer.enqueue(
            .git(
                arguments: arguments,
                repositoryPath: repositoryURL.path,
                level: level,
                exitCode: details.exitCode,
                stdout: details.stdout,
                stderr: details.stderr,
                error: error.localizedDescription,
                metadata: metadata,
                tag: tag
            ),
            appStartUptime: appStartUptime
        )
    }

    // MARK: - Private

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

    private static func runtimeMilliseconds(since appStartUptime: TimeInterval) -> Double {
        max(0, (ProcessInfo.processInfo.systemUptime - appStartUptime) * 1_000)
    }

    private static func formatMilliseconds(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
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

private final class BackgroundLogWriter: @unchecked Sendable {
    private let fileURL: URL
    private let configuration: GimMacLogger.Configuration
    private let queue = DispatchQueue(label: "io.gimmac.logging", qos: .utility)
    private var pendingWriteCount = 0

    init(fileURL: URL, configuration: GimMacLogger.Configuration) {
        self.fileURL = fileURL
        self.configuration = configuration
    }

    func enqueue(_ request: LogRequest, appStartUptime: TimeInterval) {
        guard configuration.isEnabled else { return }

        queue.async { [self] in
            let entry = Self.makeEntry(from: request, appStartUptime: appStartUptime)
            if configuration.writesToConsole {
                print(entry.consoleDescription)
            }
            append(entry)
        }
    }

    func flush(_ completion: @escaping @Sendable () -> Void) {
        queue.async(execute: completion)
    }

    private func append(_ entry: LogEntry) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            let encoder = JSONEncoder()
            let data = try encoder.encode(entry) + Data("\n".utf8)
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()

            pendingWriteCount += 1
            if pendingWriteCount >= configuration.rotationInterval {
                pendingWriteCount = 0
                rotateIfNeeded()
            }
        } catch {
            // Logging must never crash or block application work.
        }
    }

    private func rotateIfNeeded() {
        guard configuration.maxEntries > 0 else { return }

        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = contents.split(whereSeparator: \.isNewline)
            guard lines.count > configuration.maxEntries else { return }
            let trimmed = lines.suffix(configuration.maxEntries).joined(separator: "\n") + "\n"
            try trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            // Logging must never crash or block application work.
        }
    }

    private static func makeEntry(from request: LogRequest, appStartUptime: TimeInterval) -> LogEntry {
        let date = Date()
        let timestamp = Self.timestamp(from: date)
        let timeUnixNano = Self.timeUnixNano(from: date)
        let runtimeMilliseconds = max(0, (ProcessInfo.processInfo.systemUptime - appStartUptime) * 1_000)

        switch request {
        case let .event(level, category, message, metadata, tag):
            let attributes = makeAttributes(
                for: AttributeContext(kind: .event, category: category),
                metadata: metadata,
                repositoryPath: nil,
                exitCode: nil,
                tag: tag
            )
            return LogEntry(
                kind: .event,
                timestamp: timestamp,
                runtimeMilliseconds: runtimeMilliseconds,
                level: level,
                category: category,
                message: message,
                metadata: metadata,
                repositoryPath: nil,
                exitCode: nil,
                stdout: nil,
                stderr: nil,
                error: nil,
                timeUnixNano: timeUnixNano,
                observedTimeUnixNano: timeUnixNano,
                severityText: level.rawValue,
                severityNumber: level.openTelemetrySeverityNumber,
                body: message,
                attributes: attributes,
                traceID: tag?.traceID,
                spanID: tag?.spanID,
                parentSpanID: tag?.parentSpanID
            )

        case let .git(arguments, repositoryPath, level, exitCode, stdout, stderr, error, metadata, tag):
            let message = "git " + arguments.joined(separator: " ")
            let attributes = makeAttributes(
                for: AttributeContext(kind: .git, category: .git),
                metadata: metadata,
                repositoryPath: repositoryPath,
                exitCode: exitCode,
                tag: tag
            )
            return LogEntry(
                kind: .git,
                timestamp: timestamp,
                runtimeMilliseconds: runtimeMilliseconds,
                level: level,
                category: .git,
                message: message,
                metadata: metadata,
                repositoryPath: repositoryPath,
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr,
                error: error,
                timeUnixNano: timeUnixNano,
                observedTimeUnixNano: timeUnixNano,
                severityText: level.rawValue,
                severityNumber: level.openTelemetrySeverityNumber,
                body: message,
                attributes: attributes,
                traceID: tag?.traceID,
                spanID: tag?.spanID,
                parentSpanID: tag?.parentSpanID
            )
        }
    }

    private static func makeAttributes(
        for context: AttributeContext,
        metadata: [String: String],
        repositoryPath: String?,
        exitCode: Int32?,
        tag: LogFlowTag?
    ) -> [String: String] {
        var attributes = metadata
        attributes["log.kind"] = context.kind.rawValue
        attributes["log.category"] = context.category.rawValue

        if let repositoryPath {
            attributes["git.repository_path"] = repositoryPath
        }
        if let exitCode {
            attributes["git.exit_code"] = String(exitCode)
        }
        if let tag {
            attributes["flow.name"] = tag.name
            attributes["flow.started_runtime_ms"] = String(tag.startedRuntimeMilliseconds)
            for (key, value) in tag.metadata {
                attributes["flow.\(key)"] = value
            }
        }

        return attributes
    }

    private static func timestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func timeUnixNano(from date: Date) -> UInt64 {
        UInt64((date.timeIntervalSince1970 * 1_000_000_000).rounded())
    }
}

private struct AttributeContext {
    let kind: LogEntry.Kind
    let category: LogCategory
}

private enum LogRequest: Sendable {
    case event(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String],
        tag: LogFlowTag?
    )
    case git(
        arguments: [String],
        repositoryPath: String,
        level: LogLevel,
        exitCode: Int32?,
        stdout: String,
        stderr: String,
        error: String?,
        metadata: [String: String],
        tag: LogFlowTag?
    )
}

private extension LogLevel {
    var openTelemetrySeverityNumber: Int {
        switch self {
        case .debug:
            return 5
        case .info:
            return 9
        case .warning:
            return 13
        case .error:
            return 17
        }
    }
}
