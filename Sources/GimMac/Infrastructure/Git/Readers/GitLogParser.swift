import Foundation

struct GitLogParser {
    // Record separator and field separator are ASCII control characters that are
    // vastly less likely than `|` to appear in normal commit subjects.
    static let recordSeparator = "\u{1E}"
    static let fieldSeparator = "\u{1F}"
    static let logFormat = "%x1E%H%x1F%h%x1F%an%x1F%ae%x1F%at%x1F%s"

    static func parse(_ output: String) -> [Commit] {
        output
            .split(separator: Character(recordSeparator), omittingEmptySubsequences: true)
            .compactMap { record in
                let parts = String(record).split(
                    separator: Character(fieldSeparator),
                    maxSplits: 5,
                    omittingEmptySubsequences: false
                )
                guard parts.count == 6 else { return nil }

                let hash = String(parts[0])
                let shortHash = String(parts[1])
                let authorName = String(parts[2])
                let authorEmail = String(parts[3])
                let timestamp = Double(parts[4]) ?? 0
                let summary = String(parts[5])

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
