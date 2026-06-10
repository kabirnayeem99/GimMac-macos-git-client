import Foundation

/// A commit co-author. Rendered as a `Co-authored-by: Name <email>` trailer in
/// the commit message — GitHub's canonical co-author attribution format.
struct CommitAuthor: Equatable, Sendable, Identifiable, Hashable {
    let name: String
    let email: String

    var id: String { "\(name)<\(email)>" }

    /// `Co-authored-by: Name <email>` trailer line for this author.
    var trailerLine: String { "Co-authored-by: \(name) <\(email)>" }

    var display: String { "\(name) <\(email)>" }

    /// Parse a `Name <email>` token. Returns nil when name or email is missing.
    static func parse(_ raw: String) -> CommitAuthor? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "<"),
              let close = trimmed.firstIndex(of: ">"),
              open < close else { return nil }

        let name = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        let email = trimmed[trimmed.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !email.isEmpty, email.contains("@") else { return nil }

        return CommitAuthor(name: name, email: email)
    }
}
