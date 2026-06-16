import Foundation

extension GitDiffProvider {
    /// Extracts the old/new gitlink SHAs from the `-/+Subproject commit <sha>`
    /// lines, stripping any `-dirty` suffix.
    internal static func parseSubprojectSHAs(_ raw: String) -> (String?, String?) {
        var old: String?
        var new: String?
        for line in raw.components(separatedBy: "\n") {
            if line.hasPrefix("-Subproject commit ") {
                old = cleanSubprojectSHA(line.dropFirst("-Subproject commit ".count))
            } else if line.hasPrefix("+Subproject commit ") {
                new = cleanSubprojectSHA(line.dropFirst("+Subproject commit ".count))
            }
        }
        return (old, new)
    }

    private static func cleanSubprojectSHA(_ value: Substring) -> String {
        var sha = value.trimmingCharacters(in: .whitespaces)
        if sha.hasSuffix("-dirty") { sha = String(sha.dropLast("-dirty".count)) }
        return sha
    }
}
