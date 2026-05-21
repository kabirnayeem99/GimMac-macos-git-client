import Foundation

/// Parses `git for-each-ref` output into `[Branch]`.
///
/// Field order (matches `GitBranchReader.formatString`):
/// ```
/// %(refname)        full ref, e.g. refs/heads/main
/// %(refname:short)  short name,  e.g. main or origin/main
/// %(objectname)     tip SHA
/// %(objectname:short) tip short SHA
/// %(upstream:short) upstream short name (empty for none/remote refs)
/// %(authorname)     tip author
/// %(subject)        tip commit subject
/// %(creatordate:iso-strict) tip commit date, ISO-8601
/// ```
/// Fields are NUL-separated (`%00`), records are LF-separated.
struct BranchForEachRefParser {
    static let fieldSeparator = "\u{0}"
    static let fieldCount = 8

    /// The format string passed to `git for-each-ref --format=…`.
    /// Build as Swift string to avoid touching shell at any layer.
    static let formatString: String = [
        "%(refname)",
        "%(refname:short)",
        "%(objectname)",
        "%(objectname:short)",
        "%(upstream:short)",
        "%(authorname)",
        "%(subject)",
        "%(creatordate:iso-strict)"
    ].joined(separator: "%00")

    static func parse(_ output: String) -> [Branch] {
        var branches: [Branch] = []
        // Split on LF only — refs and subjects may contain whitespace but not LF
        // inside for-each-ref output, and creatordate is ISO 8601 so no LF.
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        branches.reserveCapacity(lines.count)

        for raw in lines {
            let line = String(raw)
            let parts = line.components(separatedBy: fieldSeparator)
            guard parts.count >= fieldCount else { continue }

            let refname = parts[0]
            let shortName = parts[1]
            let sha = parts[2]
            let shortSHA = parts[3]
            let upstreamRaw = parts[4]
            let authorName = parts[5]
            let subject = parts[6]
            let dateString = parts[7]

            guard !refname.isEmpty, !sha.isEmpty else { continue }

            let type: BranchType
            if refname.hasPrefix("refs/heads/") {
                type = .local
            } else if refname.hasPrefix("refs/remotes/") {
                // Short name is e.g. "origin/main" — derive the remote name as
                // the first path segment.
                let remote = shortName.split(separator: "/").first.map(String.init) ?? ""
                // Skip symbolic refs like refs/remotes/origin/HEAD which would
                // otherwise show up as a phantom branch.
                if shortName.hasSuffix("/HEAD") { continue }
                type = .remote(remoteName: remote)
            } else {
                continue
            }

            let upstream = upstreamRaw.isEmpty ? nil : upstreamRaw
            let date = Self.makeISO8601().date(from: dateString) ?? Date(timeIntervalSince1970: 0)

            let tip = BranchTip(
                sha: sha,
                shortSHA: shortSHA,
                authorName: authorName,
                summary: subject,
                date: date
            )

            branches.append(
                Branch(
                    name: shortName,
                    ref: refname,
                    tip: tip,
                    type: type,
                    upstream: upstream
                )
            )
        }
        return branches
    }

    /// New formatter per call — `ISO8601DateFormatter` is not Sendable, so we
    /// don't cache it as a static. The cost is acceptable: branch lists are
    /// short and parsing only happens on a manual refresh.
    private static func makeISO8601() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        // `iso-strict` example: 2024-05-20T13:45:22+00:00
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
