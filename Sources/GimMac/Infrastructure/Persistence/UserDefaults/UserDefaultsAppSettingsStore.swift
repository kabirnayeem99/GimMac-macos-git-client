import Foundation

/// `UserDefaults`-backed implementation of `AppSettingsStoring`. Native
/// equivalent of GitHub Desktop's localStorage-backed settings. Each property
/// maps to a namespaced key; defaults are registered once at init so first
/// reads return the GitHub-Desktop-matching defaults rather than `false`/`0`.
///
/// Only a `UserDefaults` reference is stored. `UserDefaults` is thread-safe but
/// not marked `Sendable` in the SDK, hence `@unchecked Sendable`.
final class UserDefaultsAppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    internal let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.registeredDefaults)
    }

    /// Defaults matching GitHub Desktop. Anything not listed defaults to
    /// `false` / `0` / `nil` from `UserDefaults`, which is the intended value.
    internal static var registeredDefaults: [String: Any] {[
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

    internal func enumValue<T: RawRepresentable>(forKey key: String, default fallback: T) -> T
    where T.RawValue == String {
        guard let raw = defaults.string(forKey: key), let value = T(rawValue: raw) else {
            return fallback
        }
        return value
    }

    internal func codableValue<T: Decodable>(forKey key: String, default fallback: T) -> T {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return fallback
        }
        return value
    }

    internal func setCodableValue<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
