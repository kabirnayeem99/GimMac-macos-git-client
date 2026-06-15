import Foundation

/// `UserDefaults`-backed implementation of `AppSettingsStoring`. Native
/// equivalent of GitHub Desktop's localStorage-backed settings. Each property
/// maps to a namespaced key; defaults are registered once at init so first
/// reads return the GitHub-Desktop-matching defaults rather than `false`/`0`.
///
/// Only a `UserDefaults` reference is stored. `UserDefaults` is thread-safe but
/// not marked `Sendable` in the SDK, hence `@unchecked Sendable`.
final class UserDefaultsAppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.registeredDefaults)
    }

    // MARK: - Keys

    private enum Key {
        static let prefix = "io.github.kabirnayeem99.gimmac.settings."

        static let confirmRepositoryRemoval = prefix + "confirmRepositoryRemoval"
        static let confirmDiscardChanges = prefix + "confirmDiscardChanges"
        static let confirmDiscardChangesPermanently = prefix + "confirmDiscardChangesPermanently"
        static let confirmDiscardStash = prefix + "confirmDiscardStash"
        static let confirmCheckoutCommit = prefix + "confirmCheckoutCommit"
        static let confirmForcePush = prefix + "confirmForcePush"
        static let confirmUndoCommit = prefix + "confirmUndoCommit"
        static let confirmCommitFilteredChanges = prefix + "confirmCommitFilteredChanges"

        static let uncommittedChangesStrategy = prefix + "uncommittedChangesStrategy"
        static let showCommitLengthWarning = prefix + "showCommitLengthWarning"

        static let selectedTheme = prefix + "selectedTheme"
        static let selectedTabSize = prefix + "selectedTabSize"
        static let selectedDateFormat = prefix + "selectedDateFormat"
        static let selectedTimeFormat = prefix + "selectedTimeFormat"
        static let selectedNumberFormat = prefix + "selectedNumberFormat"
        static let preferAbsoluteDates = prefix + "preferAbsoluteDates"

        static let useCustomEditor = prefix + "useCustomEditor"
        static let customEditor = prefix + "customEditor"
        static let selectedShellBundleID = prefix + "selectedShellBundleID"
        static let useCustomShell = prefix + "useCustomShell"
        static let customShell = prefix + "customShell"

        static let repositoryIndicatorsEnabled = prefix + "repositoryIndicatorsEnabled"
        static let useExternalCredentialHelper = prefix + "useExternalCredentialHelper"

        static let notificationsEnabled = prefix + "notificationsEnabled"

        static let underlineLinks = prefix + "underlineLinks"
        static let showDiffCheckMarks = prefix + "showDiffCheckMarks"
    }

    /// Defaults matching GitHub Desktop. Anything not listed defaults to
    /// `false` / `0` / `nil` from `UserDefaults`, which is the intended value.
    private static var registeredDefaults: [String: Any] {[
        Key.confirmRepositoryRemoval: true,
        Key.confirmDiscardChanges: true,
        Key.confirmDiscardChangesPermanently: true,
        Key.confirmDiscardStash: true,
        Key.confirmCheckoutCommit: true,
        Key.confirmForcePush: true,
        Key.confirmUndoCommit: true,
        Key.confirmCommitFilteredChanges: true,
        Key.uncommittedChangesStrategy: UncommittedChangesStrategy.askForConfirmation.rawValue,
        Key.showCommitLengthWarning: true,
        Key.selectedTheme: ApplicationTheme.system.rawValue,
        Key.selectedTabSize: 4,
        Key.selectedDateFormat: DateFormat.localeDefault.rawValue,
        Key.selectedTimeFormat: TimeFormat.localeDefault.rawValue,
        Key.selectedNumberFormat: NumberFormat.localeDefault.rawValue,
        Key.preferAbsoluteDates: false,
        Key.repositoryIndicatorsEnabled: true,
        Key.useExternalCredentialHelper: false,
        Key.notificationsEnabled: true,
        Key.underlineLinks: true,
        Key.showDiffCheckMarks: true
    ]}

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

    // MARK: - Helpers

    private func enumValue<T: RawRepresentable>(forKey key: String, default fallback: T) -> T
    where T.RawValue == String {
        guard let raw = defaults.string(forKey: key), let value = T(rawValue: raw) else {
            return fallback
        }
        return value
    }

    private func codableValue<T: Decodable>(forKey key: String, default fallback: T) -> T {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return fallback
        }
        return value
    }

    private func setCodableValue<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
