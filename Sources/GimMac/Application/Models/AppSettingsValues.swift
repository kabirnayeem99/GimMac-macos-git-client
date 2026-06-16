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

// MARK: - App settings value types

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
