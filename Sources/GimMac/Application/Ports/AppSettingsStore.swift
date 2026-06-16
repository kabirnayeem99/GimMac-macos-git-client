import Foundation

/// Typed accessors for user preferences persisted in `UserDefaults`. Native
/// equivalent of the localStorage-backed settings centralised in GitHub
/// Desktop's `AppStore`. Property names mirror GitHub Desktop's settings keys,
/// Swift-cased. Defaults match GitHub Desktop where applicable.
///
/// Mutations are expected from the main actor (the per-pane ViewModels);
/// `UserDefaults` itself is thread-safe, so the conforming type is `Sendable`.
protocol AppSettingsStoring: AnyObject, Sendable {
    // Confirmations — default `true` (match GitHub Desktop).
    var confirmRepositoryRemoval: Bool { get set }
    var confirmDiscardChanges: Bool { get set }
    var confirmDiscardChangesPermanently: Bool { get set }
    var confirmDiscardStash: Bool { get set }
    var confirmCheckoutCommit: Bool { get set }
    var confirmForcePush: Bool { get set }
    var confirmUndoCommit: Bool { get set }
    var confirmCommitFilteredChanges: Bool { get set }

    // Prompts
    var uncommittedChangesStrategy: UncommittedChangesStrategy { get set } // default .askForConfirmation
    var showCommitLengthWarning: Bool { get set }                          // default true

    // Appearance
    var selectedTheme: ApplicationTheme { get set }                        // default .system
    var selectedTabSize: Int { get set }                                   // default 4, clamped 1...12
    var selectedDateFormat: DateFormat { get set }
    var selectedTimeFormat: TimeFormat { get set }
    var selectedNumberFormat: NumberFormat { get set }
    var preferAbsoluteDates: Bool { get set }                              // default false

    // Integrations — external editor selection reuses the existing key.
    var selectedExternalEditorBundleID: String? { get set }
    var useCustomEditor: Bool { get set }
    var customEditor: CustomIntegration { get set }
    var selectedShellBundleID: String? { get set }
    var useCustomShell: Bool { get set }
    var customShell: CustomIntegration { get set }

    // Advanced
    var repositoryIndicatorsEnabled: Bool { get set }                      // default true
    var useExternalCredentialHelper: Bool { get set }                      // default false

    // Notifications
    var notificationsEnabled: Bool { get set }                            // default true

    // Accessibility
    var underlineLinks: Bool { get set }                                  // default true
    var showDiffCheckMarks: Bool { get set }                             // default true
}
