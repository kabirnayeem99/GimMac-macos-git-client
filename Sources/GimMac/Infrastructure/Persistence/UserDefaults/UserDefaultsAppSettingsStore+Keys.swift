import Foundation

extension UserDefaultsAppSettingsStore {
    /// Namespaced keys for each persisted setting.
    internal enum Key {
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

        static let onboardingCompleted = prefix + "onboardingCompleted"
    }
}
