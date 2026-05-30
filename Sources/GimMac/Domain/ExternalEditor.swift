import Foundation

struct ExternalEditor: Equatable, Hashable, Sendable {
    let name: String
    let bundleIdentifier: String
    let appURL: URL
}

enum ExternalEditorPreferences {
    static let selectedEditorKey = "io.github.kabirnayeem99.gimmac.selectedEditorBundleID"
}

@MainActor
protocol ExternalEditorServiceProtocol: AnyObject {
    func availableEditors() -> [ExternalEditor]
    func launch(editor: ExternalEditor, at repositoryURL: URL)
}
