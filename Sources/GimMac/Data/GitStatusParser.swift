import Foundation

struct GitStatusParser {
    static func parse(_ output: String) -> [ChangedFile] {
        let lines = output.components(separatedBy: .newlines)
        return lines.compactMap { line in
            guard line.count >= 3 else { return nil }

            let pathPart = String(line[line.index(line.startIndex, offsetBy: 3)...])

            let status: GitFileStatus
            var oldPath: String?

            // Porcelain v1 XY format: X = index (staged) state, Y = worktree (unstaged) state.
            // Read directly from the raw line (positions 0 and 1) — statusString may be trimmed
            // to a single char (e.g. "M " → "M") which makes offset-1 access unsafe.
            let xyChars = Array(line.prefix(2))
            let x = xyChars.count >= 1 ? String(xyChars[0]) : " "
            let y = xyChars.count >= 2 ? String(xyChars[1]) : " "

            let isStaged = x != " " && x != "?"
            let hasConflict = x == "U" || y == "U"
                || (x == "A" && y == "A")
                || (x == "D" && y == "D")

            switch x {
            case "A": status = .added
            case "M": status = .modified
            case "D": status = .deleted
            case "R":
                status = .renamed
                let parts = pathPart.components(separatedBy: " -> ")
                if parts.count == 2 {
                    oldPath = parts[0]
                    return ChangedFile(path: parts[1], status: status, oldPath: oldPath, isStaged: isStaged, hasConflict: hasConflict)
                }
            case "?": status = .untracked
            case "U": status = .unmerged
            case "!": status = .ignored
            default: status = .unknown
            }

            return ChangedFile(path: pathPart, status: status, oldPath: oldPath, isStaged: isStaged, hasConflict: hasConflict)
        }
    }
}
