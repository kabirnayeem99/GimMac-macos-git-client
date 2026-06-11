import Foundation

// MARK: - Appearance value types

/// App-wide appearance theme. Native equivalent of GitHub Desktop's
/// `ApplicationTheme` (`ui/lib/application-theme.ts`).
enum ApplicationTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Date display format. Mirrors GitHub Desktop's `DateFormat`
/// (`models/formatting-preferences.ts`), trimmed to the patterns GimMac offers.
enum DateFormat: String, CaseIterable, Sendable {
    case localeDefault
    case isoYearMonthDay      // YYYY-MM-DD
    case usMonthDayYear       // MM/DD/YYYY
}

/// Clock format. Mirrors GitHub Desktop's `TimeFormat`.
enum TimeFormat: String, CaseIterable, Sendable {
    case localeDefault
    case twentyFourHour
    case twelveHour
}

/// Grouping/decimal separators. Mirrors GitHub Desktop's `INumberFormat`.
enum NumberFormat: String, CaseIterable, Sendable {
    case localeDefault
    case commaGroupingDotDecimal   // 1,234.56
    case spaceGroupingCommaDecimal // 1 234,56
}

// MARK: - Prompts value types

/// What to do with uncommitted changes when switching branches. Native
/// equivalent of GitHub Desktop's `UncommittedChangesStrategy`
/// (`models/uncommitted-changes-strategy.ts`).
enum UncommittedChangesStrategy: String, CaseIterable, Sendable {
    case askForConfirmation
    case moveToNewBranch
    case stashOnCurrentBranch
}

// MARK: - App settings store

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

/// A user-configured external application (editor or shell) launched by path
/// with extra arguments. Native equivalent of GitHub Desktop's
/// `ICustomIntegration` (`lib/custom-integration.ts`). `arguments` is kept as a
/// single string mirroring the form input; tokenisation happens at launch time.
struct CustomIntegration: Equatable, Sendable, Codable {
    var path: String
    var bundleID: String?
    var arguments: String

    static let targetPathArgument = "%TARGET_PATH%"

    init(path: String = "", bundleID: String? = nil, arguments: String = CustomIntegration.targetPathArgument) {
        self.path = path
        self.bundleID = bundleID
        self.arguments = arguments
    }
}
