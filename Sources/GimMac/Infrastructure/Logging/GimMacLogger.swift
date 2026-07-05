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
        let sanitizedMessage = category == .git ? SensitiveGitDataRedactor.redact(message) : message
        let sanitizedMetadata = category == .git ? SensitiveGitDataRedactor.redact(metadata) : metadata
        writer.enqueue(
            .event(level: level, category: category, message: sanitizedMessage, metadata: sanitizedMetadata, tag: tag),
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
                arguments: SensitiveGitDataRedactor.redact(context.arguments),
                repositoryPath: context.repositoryURL.path,
                level: .debug,
                exitCode: nil,
                stdout: "",
                stderr: "",
                error: nil,
                metadata: SensitiveGitDataRedactor.redact([
                    "git.command_id": context.commandID.uuidString,
                    "git.phase": "started",
                    "git.timeout_seconds": String(context.timeout),
                    "git.extra_environment_keys": context.extraEnvironment.keys.sorted().joined(separator: ",")
                ]),
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
                arguments: SensitiveGitDataRedactor.redact(arguments),
                repositoryPath: repositoryURL.path,
                level: .info,
                exitCode: result.exitCode,
                stdout: SensitiveGitDataRedactor.redact(result.stdout),
                stderr: SensitiveGitDataRedactor.redact(result.stderr),
                error: nil,
                metadata: SensitiveGitDataRedactor.redact(metadata),
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
                arguments: SensitiveGitDataRedactor.redact(arguments),
                repositoryPath: repositoryURL.path,
                level: level,
                exitCode: details.exitCode,
                stdout: SensitiveGitDataRedactor.redact(details.stdout),
                stderr: SensitiveGitDataRedactor.redact(details.stderr),
                error: SensitiveGitDataRedactor.redact(error.localizedDescription),
                metadata: SensitiveGitDataRedactor.redact(metadata),
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
    private var fileHandle: FileHandle?
    private var recentEntryData: [Data] = []
    private var hasLoadedExistingEntries = false

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
            try ensureFileReady()
            let encoder = JSONEncoder()
            let data = try encoder.encode(entry) + Data("\n".utf8)
            let handle = try openFileHandle()
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            recentEntryData.append(data)
            trimRecentEntriesIfNeeded()
        } catch {
            // Logging must never crash or block application work.
        }
    }

    private func ensureFileReady() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard !hasLoadedExistingEntries else { return }
        hasLoadedExistingEntries = true
        guard configuration.maxEntries > 0,
              let existingData = try? Data(contentsOf: fileURL),
              !existingData.isEmpty else { return }

        recentEntryData = existingData
            .split(separator: 0x0A, omittingEmptySubsequences: true)
            .suffix(configuration.maxEntries)
            .map { Data($0) + Data("\n".utf8) }
        if existingData != Data(recentEntryData.joined()) {
            try rewriteFileFromRecentEntries()
        }
    }

    private func openFileHandle() throws -> FileHandle {
        if let fileHandle {
            return fileHandle
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        fileHandle = handle
        return handle
    }

    private func trimRecentEntriesIfNeeded() {
        guard configuration.maxEntries > 0, recentEntryData.count > configuration.maxEntries else { return }
        recentEntryData.removeFirst(recentEntryData.count - configuration.maxEntries)
        try? rewriteFileFromRecentEntries()
    }

    private func rewriteFileFromRecentEntries() throws {
        try fileHandle?.close()
        fileHandle = nil
        let rewritten = Data(recentEntryData.joined())
        try rewritten.write(to: fileURL, options: .atomic)
        fileHandle = try FileHandle(forWritingTo: fileURL)
        try fileHandle?.seekToEnd()
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
            let sanitizedArguments = SensitiveGitDataRedactor.redact(arguments)
            let sanitizedMetadata = SensitiveGitDataRedactor.redact(metadata)
            let message = "git " + sanitizedArguments.joined(separator: " ")
            let attributes = makeAttributes(
                for: AttributeContext(kind: .git, category: .git),
                metadata: sanitizedMetadata,
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
                metadata: sanitizedMetadata,
                repositoryPath: repositoryPath,
                exitCode: exitCode,
                stdout: SensitiveGitDataRedactor.redact(stdout),
                stderr: SensitiveGitDataRedactor.redact(stderr),
                error: error.map(SensitiveGitDataRedactor.redact),
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

private enum SensitiveGitDataRedactor {
    private static let replacement = "<redacted>"

    static func redact(_ text: String) -> String {
        let basicAuth = replaceMatches(
            in: text,
            pattern: #"([A-Za-z][A-Za-z0-9+\.-]*://[^/\s:@]+:)([^@\s/]+)(@)"#
        ) { match, source in
            source.substring(with: match.range(at: 1)) + replacement + source.substring(with: match.range(at: 3))
        }
        let tokenParameters = replaceMatches(
            in: basicAuth,
            pattern: #"(?i)\b(authorization|access_token|id_token|refresh_token|oauth_token|token|auth)=([^&\s]+)"#
        ) { match, source in
            source.substring(with: match.range(at: 1)) + "=" + replacement
        }
        let githubTokens = replaceMatches(in: tokenParameters, pattern: #"\bgh[pousr]_[A-Za-z0-9_]+\b"#) { _, _ in
            replacement
        }
        return replaceMatches(in: githubTokens, pattern: #"\bglpat-[A-Za-z0-9\-_]+\b"#) { _, _ in
            replacement
        }
    }

    static func redact(_ values: [String]) -> [String] {
        values.map(redact)
    }

    static func redact(_ metadata: [String: String]) -> [String: String] {
        metadata.mapValues(redact)
    }

    private static func replaceMatches(
        in text: String,
        pattern: String,
        replacementBuilder: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        let regex = regex(pattern)
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        var rewritten = ""
        var cursor = 0
        for match in matches {
            let range = match.range
            guard range.location != NSNotFound else { continue }
            rewritten += source.substring(with: NSRange(location: cursor, length: range.location - cursor))
            rewritten += replacementBuilder(match, source)
            cursor = range.location + range.length
        }
        rewritten += source.substring(from: cursor)
        return rewritten
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            preconditionFailure("Invalid sensitive-data redaction regex: \(pattern)")
        }
        return regex
    }
}
