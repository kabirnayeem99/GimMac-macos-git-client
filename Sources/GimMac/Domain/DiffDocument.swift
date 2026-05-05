import Foundation

enum DiffDocumentLineKind: Sendable {
    case context
    case added
    case removed
}

struct DiffDocumentLine: Sendable {
    let kind: DiffDocumentLineKind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String
}

struct DiffDocument: Sendable {
    let filePath: String
    let lines: [DiffDocumentLine]

    var addedCount: Int {
        lines.filter { $0.kind == .added }.count
    }

    var removedCount: Int {
        lines.filter { $0.kind == .removed }.count
    }

    static let empty = DiffDocument(filePath: "", lines: [])
}
