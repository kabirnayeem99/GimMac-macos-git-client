import Foundation

enum DiffKind {
    case context
    case added
    case removed
}

struct DiffLine: Identifiable {
    let id = UUID()
    let kind: DiffKind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String

    static func context(_ number: Int, _ text: String) -> DiffLine {
        DiffLine(kind: .context, oldNumber: number, newNumber: number, text: text)
    }

    static func added(_ number: Int, _ text: String) -> DiffLine {
        DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: text)
    }

    static func removed(_ number: Int, _ text: String) -> DiffLine {
        DiffLine(kind: .removed, oldNumber: number, newNumber: nil, text: text)
    }
}
