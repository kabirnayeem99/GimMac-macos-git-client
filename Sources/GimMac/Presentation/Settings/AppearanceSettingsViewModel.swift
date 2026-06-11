import Foundation
import Observation

/// Drives the Appearance pane of Settings: theme, diff tab size, and
/// date/time/number formatting. Native equivalent of GitHub Desktop's
/// `Appearance` preferences panel (`ui/preferences/appearance.tsx`). Persists
/// through `AppSettingsStoring`; theme changes are applied immediately via
/// `ThemeApplying`.
@MainActor
@Observable
final class AppearanceSettingsViewModel {
    var selectedTheme: ApplicationTheme {
        didSet {
            store.selectedTheme = selectedTheme
            themeApplier.apply(selectedTheme)
        }
    }
    var selectedTabSize: Int { didSet { store.selectedTabSize = selectedTabSize } }
    var selectedDateFormat: DateFormat { didSet { store.selectedDateFormat = selectedDateFormat } }
    var selectedTimeFormat: TimeFormat { didSet { store.selectedTimeFormat = selectedTimeFormat } }
    var selectedNumberFormat: NumberFormat { didSet { store.selectedNumberFormat = selectedNumberFormat } }
    var preferAbsoluteDates: Bool { didSet { store.preferAbsoluteDates = preferAbsoluteDates } }

    /// Tab sizes offered in the picker, matching GitHub Desktop's list.
    let availableTabSizes = [1, 2, 3, 4, 5, 6, 8, 10, 12]

    private let store: any AppSettingsStoring
    private let themeApplier: any ThemeApplying

    init(store: any AppSettingsStoring, themeApplier: any ThemeApplying) {
        self.store = store
        self.themeApplier = themeApplier
        selectedTheme = store.selectedTheme
        selectedTabSize = store.selectedTabSize
        selectedDateFormat = store.selectedDateFormat
        selectedTimeFormat = store.selectedTimeFormat
        selectedNumberFormat = store.selectedNumberFormat
        preferAbsoluteDates = store.preferAbsoluteDates
    }
}
