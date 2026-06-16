import Foundation

/// Parses `git status --porcelain=v2 -z` output into `[ChangedFile]`.
///
/// Porcelain v2 emits one NUL-terminated record per entry. Record kinds:
/// - `1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>` — ordinary change
/// - `2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path>` then a separate
///   NUL-terminated `<origPath>` token — rename/copy
/// - `u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>` — unmerged
/// - `? <path>` — untracked, `! <path>` — ignored
///
/// In v2 the `XY` columns use `.` (not space) for "unchanged"; X is the index
/// (staged) state and Y is the worktree state. The `<sub>` field is `N...` for a
/// normal path or `S<c><m><u>` for a submodule.
struct GitStatusParser {
    static func parse(_ output: String) -> [ChangedFile] {
        let tokens = output.split(separator: "\u{0}", omittingEmptySubsequences: true).map(String.init)
        var files: [ChangedFile] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]
            switch token.first {
            case "1":
                if let file = parseOrdinary(token) { files.append(file) }
                index += 1
            case "2":
                // Rename/copy records carry the original path as the next token.
                let original = index + 1 < tokens.count ? tokens[index + 1] : nil
                if let file = parseRenameOrCopy(token, originalPath: original) { files.append(file) }
                index += original == nil ? 1 : 2
            case "u":
                if let file = parseUnmerged(token) { files.append(file) }
                index += 1
            case "?":
                if let path = pathAfterMarker(token) {
                    files.append(makeFile(path: path, status: .untracked, isStaged: false))
                }
                index += 1
            case "!":
                if let path = pathAfterMarker(token) {
                    files.append(makeFile(path: path, status: .ignored, isStaged: false))
                }
                index += 1
            default:
                // Header lines (`#`) or anything unrecognised.
                index += 1
            }
        }
        return files
    }

    // MARK: - Record parsing

    private static func parseOrdinary(_ token: String) -> ChangedFile? {
        // Fields 0...7 are single-space separated; the path (field 8) may contain spaces.
        let parts = token.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
        guard parts.count == 9 else { return nil }
        let xy = Array(parts[1])
        guard xy.count == 2 else { return nil }
        let (status, isStaged) = classify(x: xy[0], y: xy[1])
        return ChangedFile(
            path: String(parts[8]),
            status: status,
            oldPath: nil,
            isStaged: isStaged,
            hasConflict: false,
            submoduleStatus: parseSubmodule(String(parts[2]))
        )
    }

    private static func parseRenameOrCopy(_ token: String, originalPath: String?) -> ChangedFile? {
        guard let originalPath else { return nil }
        let parts = token.split(separator: " ", maxSplits: 9, omittingEmptySubsequences: false)
        guard parts.count == 10 else { return nil }
        let xy = Array(parts[1])
        guard xy.count == 2 else { return nil }
        // Field 8 is `<X><score>` e.g. "R100" / "C75"; its leading letter is the kind.
        let status: GitFileStatus = parts[8].first == "C" ? .copied : .renamed
        return ChangedFile(
            path: String(parts[9]),
            status: status,
            oldPath: originalPath,
            isStaged: xy[0] != ".",
            hasConflict: false,
            submoduleStatus: parseSubmodule(String(parts[2]))
        )
    }

    private static func parseUnmerged(_ token: String) -> ChangedFile? {
        // `u` records have ten fields before the path (XY, sub, 4 modes, 3 hashes).
        let parts = token.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
        guard parts.count == 11 else { return nil }
        return ChangedFile(
            path: String(parts[10]),
            status: .unmerged,
            oldPath: nil,
            isStaged: false,
            hasConflict: true,
            submoduleStatus: parseSubmodule(String(parts[2]))
        )
    }

    // MARK: - Field helpers

    /// Classifies an ordinary entry from its `XY` columns: prefer the index
    /// column (X) when staged, otherwise fall back to the worktree column (Y).
    /// In v2 "unchanged" is `.`.
    private static func classify(x: Character, y: Character) -> (GitFileStatus, isStaged: Bool) {
        let isStaged = x != "."
        let code = x != "." ? x : y
        let status: GitFileStatus
        switch code {
        case "M", "T": status = .modified  // T = typechange (e.g. file ↔ symlink)
        case "A": status = .added
        case "D": status = .deleted
        case "C": status = .copied
        case "R": status = .renamed
        default: status = .unknown
        }
        return (status, isStaged)
    }

    /// Parses the `<sub>` field: `N...` → not a submodule (`nil`); `S<c><m><u>`
    /// → submodule sub-status.
    private static func parseSubmodule(_ field: String) -> SubmoduleStatus? {
        let chars = Array(field)
        guard chars.count == 4, chars[0] == "S" else { return nil }
        return SubmoduleStatus(
            commitChanged: chars[1] == "C",
            modifiedChanges: chars[2] == "M",
            untrackedChanges: chars[3] == "U"
        )
    }

    /// Extracts the path from a `? <path>` / `! <path>` record. Drops the single
    /// marker character and exactly one separator space, so a path that itself
    /// begins with spaces is preserved intact.
    private static func pathAfterMarker(_ token: String) -> String? {
        var rest = token.dropFirst()           // drop the '?' / '!' marker
        guard rest.first == " " else { return nil }
        rest = rest.dropFirst()                // drop the single separator space
        return rest.isEmpty ? nil : String(rest)
    }

    private static func makeFile(path: String, status: GitFileStatus, isStaged: Bool) -> ChangedFile {
        ChangedFile(path: path, status: status, oldPath: nil, isStaged: isStaged, hasConflict: false)
    }
}
