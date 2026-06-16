import Foundation

enum DiffKind {
    case context
    case added
    case removed
    case hunk
}

struct DiffLineHighlight: Equatable {
    let location: Int
    let length: Int
}

struct DiffLine: Identifiable {
    let id = UUID()
    let kind: DiffKind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String
    let highlight: DiffLineHighlight?

    static func context(_ number: Int, _ text: String) -> DiffLine {
        DiffLine(kind: .context, oldNumber: number, newNumber: number, text: text, highlight: nil)
    }

    static func added(_ number: Int, _ text: String) -> DiffLine {
        DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: text, highlight: nil)
    }

    static func removed(_ number: Int, _ text: String) -> DiffLine {
        DiffLine(kind: .removed, oldNumber: number, newNumber: nil, text: text, highlight: nil)
    }

    static func hunk(_ text: String) -> DiffLine {
        DiffLine(kind: .hunk, oldNumber: nil, newNumber: nil, text: text, highlight: nil)
    }

    func highlighted(_ highlight: DiffLineHighlight?) -> DiffLine {
        DiffLine(kind: kind, oldNumber: oldNumber, newNumber: newNumber, text: text, highlight: highlight)
    }
}

enum DiffLineHighlighter {
    private static let maxIntralineDiffLength = 1_024

    static func highlighted(_ lines: [DiffLine]) -> [DiffLine] {
        var highlightedLines = lines
        var modifiedStart: Int?

        for index in 0...highlightedLines.count {
            let isModifiedLine: Bool
            if index < highlightedLines.count {
                isModifiedLine = highlightedLines[index].kind == .added || highlightedLines[index].kind == .removed
            } else {
                isModifiedLine = false
            }

            if isModifiedLine {
                if modifiedStart == nil {
                    modifiedStart = index
                }
                continue
            }

            if let start = modifiedStart {
                applyHighlights(to: &highlightedLines, range: start..<index)
                modifiedStart = nil
            }
        }

        return highlightedLines
    }

    private static func applyHighlights(to lines: inout [DiffLine], range: Range<Int>) {
        let removedIndices = range.filter { lines[$0].kind == .removed }
        let addedIndices = range.filter { lines[$0].kind == .added }

        guard removedIndices.count == addedIndices.count else { return }

        for (removedIndex, addedIndex) in zip(removedIndices, addedIndices) {
            let removedText = lines[removedIndex].text
            let addedText = lines[addedIndex].text

            guard removedText.count < maxIntralineDiffLength,
                  addedText.count < maxIntralineDiffLength else { continue }

            let ranges = relativeChanges(from: removedText, to: addedText)
            if ranges.removed.length > 0 {
                lines[removedIndex] = lines[removedIndex].highlighted(ranges.removed)
            }
            if ranges.added.length > 0 {
                lines[addedIndex] = lines[addedIndex].highlighted(ranges.added)
            }
        }
    }

    private static func relativeChanges(
        from removedText: String,
        to addedText: String
    ) -> (removed: DiffLineHighlight, added: DiffLineHighlight) {
        let removed = Array(removedText)
        let added = Array(addedText)
        let sharedLimit = min(removed.count, added.count)

        var prefixLength = 0
        while prefixLength < sharedLimit, removed[prefixLength] == added[prefixLength] {
            prefixLength += 1
        }

        var suffixLength = 0
        while suffixLength < sharedLimit - prefixLength,
              removed[removed.count - suffixLength - 1] == added[added.count - suffixLength - 1] {
            suffixLength += 1
        }

        return (
            removed: DiffLineHighlight(
                location: prefixLength,
                length: removed.count - prefixLength - suffixLength
            ),
            added: DiffLineHighlight(
                location: prefixLength,
                length: added.count - prefixLength - suffixLength
            )
        )
    }
}
