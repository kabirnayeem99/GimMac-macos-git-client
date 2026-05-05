import Foundation

struct GitLogParser {
    // Format: %H|%h|%an|%ae|%at|%s
    // %H: commit hash
    // %h: abbreviated commit hash
    // %an: author name
    // %ae: author email
    // %at: author date, UNIX timestamp
    // %s: subject
    static let logFormat = "%H|%h|%an|%ae|%at|%s"
    static let separator = "|"

    static func parse(_ output: String) -> [Commit] {
        let lines = output.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let parts = line.components(separatedBy: separator)
            guard parts.count >= 6 else { return nil }

            let hash = parts[0]
            let shortHash = parts[1]
            let authorName = parts[2]
            let authorEmail = parts[3]
            let timestamp = Double(parts[4]) ?? 0
            let summary = parts[5]

            return Commit(
                id: hash,
                shortHash: shortHash,
                authorName: authorName,
                authorEmail: authorEmail,
                date: Date(timeIntervalSince1970: timestamp),
                summary: summary,
                body: nil // Body handling could be added later with %b
            )
        }
    }
}
