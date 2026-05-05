import Foundation

// Vendored and adapted from https://github.com/michaelneale/swifty-diff (MIT).
// This parser reads unified git diff text into structured files/hunks/lines.
enum SwiftyDiffUnifiedParser {
    struct ParsedFile {
        let path: String
        let oldPath: String?
        let hunks: [ParsedHunk]
    }

    struct ParsedHunk {
        let header: String
        let oldStart: Int
        let oldCount: Int
        let newStart: Int
        let newCount: Int
        let lines: [ParsedLine]
    }

    enum LineType {
        case context
        case addition
        case deletion
    }

    struct ParsedLine {
        let type: LineType
        let content: String
        let oldLineNumber: Int?
        let newLineNumber: Int?
    }

    static func parse(_ diff: String) -> [ParsedFile] {
        var files: [ParsedFile] = []
        let lines = diff.components(separatedBy: "\n")

        var i = 0
        while i < lines.count {
            if lines[i].hasPrefix("diff --git") {
                let (file, next) = parseFile(lines: lines, startIndex: i)
                if let file {
                    files.append(file)
                }
                i = next
            } else {
                i += 1
            }
        }

        return files
    }

    private static func parseFile(lines: [String], startIndex: Int) -> (ParsedFile?, Int) {
        var i = startIndex
        var path = ""
        var oldPath: String?
        var hunks: [ParsedHunk] = []

        if i < lines.count && lines[i].hasPrefix("diff --git") {
            let components = lines[i].components(separatedBy: " ")
            if components.count >= 4 {
                oldPath = String(components[2].dropFirst(2))
                path = String(components[3].dropFirst(2))
            }
            i += 1
        }

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("diff --git") {
                break
            } else if line.hasPrefix("rename from") {
                oldPath = String(line.dropFirst("rename from ".count))
                i += 1
            } else if line.hasPrefix("rename to") {
                path = String(line.dropFirst("rename to ".count))
                i += 1
            } else if line.hasPrefix("@@") {
                let (hunk, next) = parseHunk(lines: lines, startIndex: i)
                if let hunk {
                    hunks.append(hunk)
                }
                i = next
            } else {
                i += 1
            }
        }

        guard !path.isEmpty else {
            return (nil, i)
        }

        return (ParsedFile(path: path, oldPath: oldPath, hunks: hunks), i)
    }

    private static func parseHunk(lines: [String], startIndex: Int) -> (ParsedHunk?, Int) {
        var i = startIndex
        let headerLine = lines[i]

        let pattern = #"@@\s*-([0-9]+),?([0-9]*)\s*\+([0-9]+),?([0-9]*)\s*@@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: headerLine, range: NSRange(headerLine.startIndex..., in: headerLine)) else {
            return (nil, i + 1)
        }

        let oldStart = Int((headerLine as NSString).substring(with: match.range(at: 1))) ?? 0
        let oldCountStr = (headerLine as NSString).substring(with: match.range(at: 2))
        let oldCount = oldCountStr.isEmpty ? 1 : (Int(oldCountStr) ?? 1)
        let newStart = Int((headerLine as NSString).substring(with: match.range(at: 3))) ?? 0
        let newCountStr = (headerLine as NSString).substring(with: match.range(at: 4))
        let newCount = newCountStr.isEmpty ? 1 : (Int(newCountStr) ?? 1)

        i += 1

        var parsedLines: [ParsedLine] = []
        var oldLineNum = oldStart
        var newLineNum = newStart

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("@@") || line.hasPrefix("diff --git") {
                break
            }

            if line.hasPrefix("+") {
                parsedLines.append(
                    ParsedLine(type: .addition, content: String(line.dropFirst()), oldLineNumber: nil, newLineNumber: newLineNum)
                )
                newLineNum += 1
            } else if line.hasPrefix("-") {
                parsedLines.append(
                    ParsedLine(type: .deletion, content: String(line.dropFirst()), oldLineNumber: oldLineNum, newLineNumber: nil)
                )
                oldLineNum += 1
            } else if line.hasPrefix(" ") {
                parsedLines.append(
                    ParsedLine(type: .context, content: String(line.dropFirst()), oldLineNumber: oldLineNum, newLineNumber: newLineNum)
                )
                oldLineNum += 1
                newLineNum += 1
            } else {
                parsedLines.append(
                    ParsedLine(type: .context, content: line, oldLineNumber: oldLineNum, newLineNumber: newLineNum)
                )
                oldLineNum += 1
                newLineNum += 1
            }

            i += 1
        }

        return (
            ParsedHunk(
                header: headerLine,
                oldStart: oldStart,
                oldCount: oldCount,
                newStart: newStart,
                newCount: newCount,
                lines: parsedLines
            ),
            i
        )
    }
}
