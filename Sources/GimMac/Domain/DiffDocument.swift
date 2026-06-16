import Foundation

enum DiffDocumentLineKind: Sendable {
    case context
    case added
    case removed
    case hunk
}

struct DiffDocumentLine: Sendable {
    let kind: DiffDocumentLineKind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String
}

/// A base64-encoded image blob with its media type, used to render image diffs.
/// GitHub Desktop equivalent: `Image` in `models/diff/image.ts`.
struct ImageDiffContent: Sendable, Equatable {
    /// e.g. `image/png`, `image/jpg`.
    let mediaType: String
    /// Base64-encoded raw bytes.
    let base64Contents: String
}

/// The before/after image data for an image diff. Either side may be `nil`
/// (a new image has no `previous`; a deleted image has no `current`).
struct ImageDiffData: Sendable, Equatable {
    let previous: ImageDiffContent?
    let current: ImageDiffContent?
}

/// The diff of a changed submodule gitlink.
/// GitHub Desktop equivalent: `ISubmoduleDiff` in `models/diff/diff-data.ts`.
struct SubmoduleDiffData: Sendable, Equatable {
    /// Submodule path relative to the superproject, always '/'-separated.
    let path: String
    /// Absolute path to the submodule working directory.
    let fullPath: String
    /// Gitlink SHAs — both `nil` unless the recorded commit changed.
    let oldSHA: String?
    let newSHA: String?
    let commitChanged: Bool
    let modifiedChanges: Bool
    let untrackedChanges: Bool
}

/// Discriminates how a `DiffDocument` should be rendered.
/// GitHub Desktop equivalent: `DiffType`. (Distinct from the presentation-layer
/// `DiffKind` line type in `Presentation/Diff/DiffModels.swift`.)
enum DiffContentKind: Sendable, Equatable {
    case text
    case binary
    case image(ImageDiffData)
    case submodule(SubmoduleDiffData)
}

struct DiffDocument: Sendable {
    let filePath: String
    let lines: [DiffDocumentLine]
    let kind: DiffContentKind

    init(filePath: String, lines: [DiffDocumentLine], kind: DiffContentKind = .text) {
        self.filePath = filePath
        self.lines = lines
        self.kind = kind
    }

    var addedCount: Int {
        lines.filter { $0.kind == .added }.count
    }

    var removedCount: Int {
        lines.filter { $0.kind == .removed }.count
    }

    var isBinary: Bool {
        if case .binary = kind { return true }
        return false
    }

    static let empty = DiffDocument(filePath: "", lines: [])
}
