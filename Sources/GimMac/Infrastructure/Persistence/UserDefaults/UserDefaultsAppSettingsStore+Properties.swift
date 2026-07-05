import Foundation

extension UserDefaultsAppSettingsStore {
    // MARK: - Confirmations

    var confirmRepositoryRemoval: Bool {
        get { defaults.bool(forKey: Key.confirmRepositoryRemoval) }
        set { defaults.set(newValue, forKey: Key.confirmRepositoryRemoval) }
    }
    var confirmDiscardChanges: Bool {
        get { defaults.bool(forKey: Key.confirmDiscardChanges) }
        set { defaults.set(newValue, forKey: Key.confirmDiscardChanges) }
    }
    var confirmDiscardChangesPermanently: Bool {
        get { defaults.bool(forKey: Key.confirmDiscardChangesPermanently) }
        set { defaults.set(newValue, forKey: Key.confirmDiscardChangesPermanently) }
    }
    var confirmDiscardStash: Bool {
        get { defaults.bool(forKey: Key.confirmDiscardStash) }
        set { defaults.set(newValue, forKey: Key.confirmDiscardStash) }
    }
    var confirmCheckoutCommit: Bool {
        get { defaults.bool(forKey: Key.confirmCheckoutCommit) }
        set { defaults.set(newValue, forKey: Key.confirmCheckoutCommit) }
    }
    var confirmForcePush: Bool {
        get { defaults.bool(forKey: Key.confirmForcePush) }
        set { defaults.set(newValue, forKey: Key.confirmForcePush) }
    }
    var confirmUndoCommit: Bool {
        get { defaults.bool(forKey: Key.confirmUndoCommit) }
        set { defaults.set(newValue, forKey: Key.confirmUndoCommit) }
    }
    var confirmCommitFilteredChanges: Bool {
        get { defaults.bool(forKey: Key.confirmCommitFilteredChanges) }
        set { defaults.set(newValue, forKey: Key.confirmCommitFilteredChanges) }
    }

    // MARK: - Prompts

    var uncommittedChangesStrategy: UncommittedChangesStrategy {
        get { enumValue(forKey: Key.uncommittedChangesStrategy, default: .askForConfirmation) }
        set { defaults.set(newValue.rawValue, forKey: Key.uncommittedChangesStrategy) }
    }
    var showCommitLengthWarning: Bool {
        get { defaults.bool(forKey: Key.showCommitLengthWarning) }
        set { defaults.set(newValue, forKey: Key.showCommitLengthWarning) }
    }

    // MARK: - Appearance

    var selectedTheme: ApplicationTheme {
        get { enumValue(forKey: Key.selectedTheme, default: .system) }
        set { defaults.set(newValue.rawValue, forKey: Key.selectedTheme) }
    }
    var selectedTabSize: Int {
        get { min(12, max(1, defaults.integer(forKey: Key.selectedTabSize))) }
        set { defaults.set(min(12, max(1, newValue)), forKey: Key.selectedTabSize) }
    }
    var selectedDateFormat: DateFormat {
        get { enumValue(forKey: Key.selectedDateFormat, default: .localeDefault) }
        set { defaults.set(newValue.rawValue, forKey: Key.selectedDateFormat) }
    }
    var selectedTimeFormat: TimeFormat {
        get { enumValue(forKey: Key.selectedTimeFormat, default: .localeDefault) }
        set { defaults.set(newValue.rawValue, forKey: Key.selectedTimeFormat) }
    }
    var selectedNumberFormat: NumberFormat {
        get { enumValue(forKey: Key.selectedNumberFormat, default: .localeDefault) }
        set { defaults.set(newValue.rawValue, forKey: Key.selectedNumberFormat) }
    }
    var preferAbsoluteDates: Bool {
        get { defaults.bool(forKey: Key.preferAbsoluteDates) }
        set { defaults.set(newValue, forKey: Key.preferAbsoluteDates) }
    }

    // MARK: - Integrations

    /// Reuses the historical external-editor key so existing selections survive.
    var selectedExternalEditorBundleID: String? {
        get { defaults.string(forKey: ExternalEditorPreferences.selectedEditorKey) }
        set { defaults.set(newValue, forKey: ExternalEditorPreferences.selectedEditorKey) }
    }
    var useCustomEditor: Bool {
        get { defaults.bool(forKey: Key.useCustomEditor) }
        set { defaults.set(newValue, forKey: Key.useCustomEditor) }
    }
    var customEditor: CustomIntegration {
        get { codableValue(forKey: Key.customEditor, default: CustomIntegration()) }
        set { setCodableValue(newValue, forKey: Key.customEditor) }
    }
    var selectedShellBundleID: String? {
        get { defaults.string(forKey: Key.selectedShellBundleID) }
        set { defaults.set(newValue, forKey: Key.selectedShellBundleID) }
    }
    var useCustomShell: Bool {
        get { defaults.bool(forKey: Key.useCustomShell) }
        set { defaults.set(newValue, forKey: Key.useCustomShell) }
    }
    var customShell: CustomIntegration {
        get { codableValue(forKey: Key.customShell, default: CustomIntegration()) }
        set { setCodableValue(newValue, forKey: Key.customShell) }
    }

    // MARK: - Advanced

    var repositoryIndicatorsEnabled: Bool {
        get { defaults.bool(forKey: Key.repositoryIndicatorsEnabled) }
        set { defaults.set(newValue, forKey: Key.repositoryIndicatorsEnabled) }
    }
    var useExternalCredentialHelper: Bool {
        get { defaults.bool(forKey: Key.useExternalCredentialHelper) }
        set { defaults.set(newValue, forKey: Key.useExternalCredentialHelper) }
    }

    // MARK: - Notifications

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { defaults.set(newValue, forKey: Key.notificationsEnabled) }
    }

    // MARK: - Accessibility

    var underlineLinks: Bool {
        get { defaults.bool(forKey: Key.underlineLinks) }
        set { defaults.set(newValue, forKey: Key.underlineLinks) }
    }
    var showDiffCheckMarks: Bool {
        get { defaults.bool(forKey: Key.showDiffCheckMarks) }
        set { defaults.set(newValue, forKey: Key.showDiffCheckMarks) }
    }

    // MARK: - Onboarding

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Key.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Key.onboardingCompleted) }
    }
}
