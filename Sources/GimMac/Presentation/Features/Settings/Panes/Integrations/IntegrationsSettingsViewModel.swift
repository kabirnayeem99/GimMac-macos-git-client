import Foundation
import Observation

/// Drives the Integrations pane of Settings: external editor and shell
/// selection, plus custom (path + arguments) integrations. Native equivalent
/// of GitHub Desktop's `Integrations` preferences panel
/// (`ui/preferences/integrations.tsx`). Selections persist through
/// `AppSettingsStoring`.
@MainActor
@Observable
final class IntegrationsSettingsViewModel {
    private(set) var availableEditors: [ExternalEditor] = []
    private(set) var availableShells: [TerminalShell] = []

    var selectedEditorBundleID: String? {
        didSet { store.selectedExternalEditorBundleID = selectedEditorBundleID }
    }
    var useCustomEditor: Bool { didSet { store.useCustomEditor = useCustomEditor } }
    var customEditor: CustomIntegration { didSet { store.customEditor = customEditor } }

    var selectedShellBundleID: String? {
        didSet { store.selectedShellBundleID = selectedShellBundleID }
    }
    var useCustomShell: Bool { didSet { store.useCustomShell = useCustomShell } }
    var customShell: CustomIntegration { didSet { store.customShell = customShell } }

    private let store: any AppSettingsStoring
    private let editorService: any ExternalEditorServiceProtocol
    private let shellService: any ShellServiceProtocol

    init(
        store: any AppSettingsStoring,
        editorService: any ExternalEditorServiceProtocol,
        shellService: any ShellServiceProtocol
    ) {
        self.store = store
        self.editorService = editorService
        self.shellService = shellService
        selectedEditorBundleID = store.selectedExternalEditorBundleID
        useCustomEditor = store.useCustomEditor
        customEditor = store.customEditor
        selectedShellBundleID = store.selectedShellBundleID
        useCustomShell = store.useCustomShell
        customShell = store.customShell
    }

    /// Discovers installed editors/shells and falls back to the first available
    /// one when the stored selection is missing or no longer installed.
    func reloadAvailableIntegrations() {
        availableEditors = editorService.availableEditors()
        availableShells = shellService.availableShells()

        if !useCustomEditor,
           selectedEditorBundleID == nil
            || !availableEditors.contains(where: { $0.bundleIdentifier == selectedEditorBundleID }) {
            selectedEditorBundleID = availableEditors.first?.bundleIdentifier
        }

        if !useCustomShell,
           selectedShellBundleID == nil
            || !availableShells.contains(where: { $0.bundleIdentifier == selectedShellBundleID }) {
            selectedShellBundleID = availableShells.first?.bundleIdentifier
        }
    }
}
