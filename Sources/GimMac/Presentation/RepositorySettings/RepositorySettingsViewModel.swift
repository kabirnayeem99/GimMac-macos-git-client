import AppKit
import Observation

@Observable
@MainActor
final class RepositorySettingsViewModel {

    // MARK: - State

    var remoteURL: String = ""
    var pendingRemoteURL: String = ""
    var currentBranchName: String = ""
    var newBranchName: String = ""
    var lfsAvailable: Bool = false
    var isLoadingRemote: Bool = false
    var isLoadingLFS: Bool = false
    var isSavingRemote: Bool = false
    var isSavingBranch: Bool = false
    var isInitializingLFS: Bool = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: - Dependencies

    let repositoryURL: URL
    private let remoteProvider: any RepositoryRemoteProviding
    private let lfsProvider: any LFSProviding
    private let branchRenamer: any DefaultBranchRenaming
    private let editorService: any ExternalEditorServiceProtocol

    var onDismiss: (() -> Void)?

    // MARK: - Init

    init(
        repositoryURL: URL,
        currentBranchName: String,
        remoteProvider: any RepositoryRemoteProviding,
        lfsProvider: any LFSProviding,
        branchRenamer: any DefaultBranchRenaming,
        editorService: any ExternalEditorServiceProtocol
    ) {
        self.repositoryURL = repositoryURL
        self.currentBranchName = currentBranchName
        self.newBranchName = currentBranchName
        self.remoteProvider = remoteProvider
        self.lfsProvider = lfsProvider
        self.branchRenamer = branchRenamer
        self.editorService = editorService
    }

    // MARK: - Remote

    func loadRemoteURL() async {
        isLoadingRemote = true
        defer { isLoadingRemote = false }
        do {
            let url = try await remoteProvider.fetchRemoteURL(named: "origin", in: repositoryURL)
            remoteURL = url ?? ""
            pendingRemoteURL = remoteURL
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    func saveRemoteURL() async {
        let trimmed = pendingRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != remoteURL else { return }
        isSavingRemote = true
        defer { isSavingRemote = false }
        errorMessage = nil
        do {
            try await remoteProvider.setRemoteURL(trimmed, named: "origin", in: repositoryURL)
            remoteURL = trimmed
            successMessage = "Remote URL updated."
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    // MARK: - Default Branch

    func renameCurrentBranch() async {
        let trimmed = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentBranchName else { return }
        isSavingBranch = true
        defer { isSavingBranch = false }
        errorMessage = nil
        do {
            try await branchRenamer.renameCurrentBranch(from: currentBranchName, to: trimmed, in: repositoryURL)
            currentBranchName = trimmed
            successMessage = "Branch renamed to '\(trimmed)'."
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    // MARK: - Git LFS

    func checkLFSAvailability() async {
        isLoadingLFS = true
        defer { isLoadingLFS = false }
        lfsAvailable = (try? await lfsProvider.isLFSAvailable(in: repositoryURL)) ?? false
    }

    func initializeLFS() async {
        isInitializingLFS = true
        defer { isInitializingLFS = false }
        errorMessage = nil
        do {
            try await lfsProvider.initializeLFS(in: repositoryURL)
            lfsAvailable = true
            successMessage = "Git LFS initialized for this repository."
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    // MARK: - Open In

    func openInTerminal() {
        guard let terminalURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Terminal"
        ) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [repositoryURL],
            withApplicationAt: terminalURL,
            configuration: config
        )
    }

    func openInExternalEditor() {
        let editors = editorService.availableEditors()
        let savedID = UserDefaults.standard.string(forKey: ExternalEditorPreferences.selectedEditorKey)
        guard let editor = editors.first(where: { $0.bundleIdentifier == savedID }) ?? editors.first else {
            errorMessage = "No external editor configured. Set one in Settings → Integrations."
            return
        }
        editorService.launch(editor: editor, at: repositoryURL)
    }

    // MARK: - Helpers

    private func errorDescription(_ error: Error) -> String {
        (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
    }
}
