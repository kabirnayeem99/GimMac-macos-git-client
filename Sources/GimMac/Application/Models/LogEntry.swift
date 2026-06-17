import Foundation

struct LogEntry: Codable, Sendable {
    enum Kind: String, Codable {
        case git
        case event
    }

    let kind: Kind
    let timestamp: String
    let runtimeMilliseconds: Double?

    // Event fields
    let level: LogLevel
    let category: LogCategory
    let message: String
    let metadata: [String: String]

    // Git-only fields (nil for event entries)
    let repositoryPath: String?
    let exitCode: Int32?
    let stdout: String?
    let stderr: String?
    let error: String?

    // OpenTelemetry-compatible fields
    let timeUnixNano: UInt64?
    let observedTimeUnixNano: UInt64?
    let severityText: String?
    let severityNumber: Int?
    let body: String?
    let attributes: [String: String]?
    let traceID: String?
    let spanID: String?
    let parentSpanID: String?

    init(
        kind: Kind,
        timestamp: String,
        runtimeMilliseconds: Double? = nil,
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String],
        repositoryPath: String?,
        exitCode: Int32?,
        stdout: String?,
        stderr: String?,
        error: String?,
        timeUnixNano: UInt64? = nil,
        observedTimeUnixNano: UInt64? = nil,
        severityText: String? = nil,
        severityNumber: Int? = nil,
        body: String? = nil,
        attributes: [String: String]? = nil,
        traceID: String? = nil,
        spanID: String? = nil,
        parentSpanID: String? = nil
    ) {
        self.kind = kind
        self.timestamp = timestamp
        self.runtimeMilliseconds = runtimeMilliseconds
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.repositoryPath = repositoryPath
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.error = error
        self.timeUnixNano = timeUnixNano
        self.observedTimeUnixNano = observedTimeUnixNano
        self.severityText = severityText
        self.severityNumber = severityNumber
        self.body = body
        self.attributes = attributes
        self.traceID = traceID
        self.spanID = spanID
        self.parentSpanID = parentSpanID
    }
}

extension LogEntry {
    var consoleDescription: String {
        let time = timestamp.components(separatedBy: "T").last.map { String($0.dropLast()) } ?? timestamp

        switch kind {
        case .git:
            let ok = exitCode == 0
            let mark = ok ? "✓" : "✗"
            let lvl  = ok ? "GIT  \(mark)" : "GIT  \(mark)"
            var lines = ["[\(time)]  \(lvl)  \(message)"]
            if let code = exitCode, code != 0 {
                lines[0] += "  exit=\(code)"
            }
            if let err = stderr, !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("             STDERR: \(err.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if let out = stdout, !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("             STDOUT: \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if let err = error {
                lines.append("             ERROR:  \(err)")
            }
            return lines.joined(separator: "\n")

        case .event:
            let lvl = level.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)
            let cat = "[\(category.rawValue)]".padding(toLength: 12, withPad: " ", startingAt: 0)
            var line = "[\(time)]  \(lvl)  \(cat)  \(message)"
            if !metadata.isEmpty {
                let pairs = metadata.sorted(by: { $0.key < $1.key })
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: " | ")
                line += "  |  \(pairs)"
            }
            return line
        }
    }
}
