import Foundation

struct GitStatusParser {
    static func parse(_ output: String) -> [ChangedFile] {
        let lines = output.components(separatedBy: .newlines)
        return lines.compactMap { line in
            guard line.count >= 3 else { return nil }

            let startIndex = line.index(line.startIndex, offsetBy: 0)
            let endIndex = line.index(line.startIndex, offsetBy: 2)
            let statusString = String(line[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)

            let pathPart = String(line[line.index(line.startIndex, offsetBy: 3)...])

            let status: GitFileStatus
            var oldPath: String?

            // First character is Index, second is Work Tree
            // For MVP, we'll map them to a simplified GitFileStatus
            let primaryStatus = statusString.first.map(String.init) ?? "X"

            switch primaryStatus {
            case "A": status = .added
            case "M": status = .modified
            case "D": status = .deleted
            case "R":
                status = .renamed
                let parts = pathPart.components(separatedBy: " -> ")
                if parts.count == 2 {
                    oldPath = parts[0]
                    // The path is the new path
                    return ChangedFile(path: parts[1], status: status, oldPath: oldPath)
                }
            case "?": status = .untracked
            case "U": status = .unmerged
            case "!": status = .ignored
            default: status = .unknown
            }

            return ChangedFile(path: pathPart, status: status, oldPath: oldPath)
        }
    }
}
