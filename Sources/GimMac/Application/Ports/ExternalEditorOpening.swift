import Foundation

@MainActor
protocol ExternalEditorServiceProtocol: AnyObject {
    func availableEditors() -> [ExternalEditor]
    func launch(editor: ExternalEditor, at repositoryURL: URL)
}
