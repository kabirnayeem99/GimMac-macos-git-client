import Foundation

struct LogEntry: Codable, Sendable {
    enum Kind: String, Codable {
        case git
        case event
    }

    let kind: Kind
    let timestamp: String

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
