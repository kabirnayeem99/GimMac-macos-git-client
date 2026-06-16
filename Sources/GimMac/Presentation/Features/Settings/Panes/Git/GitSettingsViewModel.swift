import Foundation
import Observation

/// Drives the Git pane of Settings: global author identity and the default
/// branch name for new repositories. Native equivalent of GitHub Desktop's
/// `Git` preferences panel (`ui/preferences/git.tsx`). Reads/writes the global
/// Git config via `GitConfigReading` / `GitConfigWriting`.
@MainActor
@Observable
final class GitSettingsViewModel {
    var committerName: String = ""
    var committerEmail: String = ""
    var defaultBranch: String = ""

    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var successMessage: String?

    /// Non-nil when the entered name contains only disallowed characters.
    /// Mirrors GitHub Desktop's `gitAuthorNameIsValid` / `InvalidGitAuthorNameMessage`.
    var nameValidationMessage: String? {
        Self.isAuthorNameValid(committerName) ? nil : Self.invalidAuthorNameMessage
    }

    private var initialName: String?
    private var initialEmail: String?
    private var initialDefaultBranch: String?

    private let configReader: any GitConfigReading
    private let configWriter: any GitConfigWriting

    init(configReader: any GitConfigReading, configWriter: any GitConfigWriting) {
        self.configReader = configReader
        self.configWriter = configWriter
    }

    func load() async {
        guard !hasLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let name = try await configReader.globalUserName()
            let email = try await configReader.globalUserEmail()
            let branch = try await configReader.globalDefaultBranch()
            initialName = name
            initialEmail = email
            initialDefaultBranch = branch
            committerName = name ?? ""
            committerEmail = email ?? ""
            defaultBranch = branch ?? ""
            hasLoaded = true
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    /// Persists only the fields that changed, mirroring GitHub Desktop's save
    /// logic. An empty default branch is left untouched (keeps the prior value),
    /// matching GitHub Desktop's behaviour.
    func save() async {
        guard !isSaving, nameValidationMessage == nil else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        successMessage = nil
        do {
            if committerName != (initialName ?? "") {
                try await configWriter.setGlobalUserName(committerName)
                initialName = committerName
            }
            if committerEmail != (initialEmail ?? "") {
                try await configWriter.setGlobalUserEmail(committerEmail)
                initialEmail = committerEmail
            }
            let trimmedBranch = defaultBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBranch.isEmpty, trimmedBranch != (initialDefaultBranch ?? "") {
                try await configWriter.setGlobalDefaultBranch(trimmedBranch)
                initialDefaultBranch = trimmedBranch
            }
            successMessage = "Git settings saved."
        } catch {
            errorMessage = errorDescription(error)
        }
    }

    // MARK: - Validation

    static let invalidAuthorNameMessage =
        "Name is invalid, it consists only of disallowed characters."

    /// A name is valid if, after stripping characters Git disallows in an
    /// author identity (`<`, `>`, newlines, control characters), something
    /// non-empty remains — or the field is empty (treated as "not set").
    static func isAuthorNameValid(_ name: String) -> Bool {
        if name.isEmpty { return true }
        let disallowed = CharacterSet(charactersIn: "<>\n\r").union(.controlCharacters)
        let stripped = name.components(separatedBy: disallowed).joined()
        return !stripped.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func errorDescription(_ error: Error) -> String {
        (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
    }
}
