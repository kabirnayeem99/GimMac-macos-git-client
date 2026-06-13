import AppKit

/// Appearance pane: theme, diff tab size, and date/time/number formatting.
/// Native equivalent of GitHub Desktop's `Appearance` preferences panel.
@MainActor
final class AppearanceSettingsPaneController: SettingsPaneViewController {
    private let viewModel: AppearanceSettingsViewModel

    private static let themeOrder: [ApplicationTheme] = [.system, .light, .dark]
    private static let themeTitles = ["System", "Light", "Dark"]
    private static let dateOrder: [DateFormat] = [.localeDefault, .isoYearMonthDay, .usMonthDayYear]
    private static let dateTitles = ["Locale default", "YYYY-MM-DD", "MM/DD/YYYY"]
    private static let timeOrder: [TimeFormat] = [.localeDefault, .twentyFourHour, .twelveHour]
    private static let timeTitles = ["Locale default", "24-hour", "12-hour"]
    private static let numberOrder: [NumberFormat] = [.localeDefault, .commaGroupingDotDecimal, .spaceGroupingCommaDecimal]
    private static let numberTitles = ["Locale default", "1,234.56", "1 234,56"]

    init(viewModel: AppearanceSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        addHeader("Appearance")

        let themeIndex = Self.themeOrder.firstIndex(of: viewModel.selectedTheme) ?? 0
        addSection("Theme", views: [
            labeledRow("Theme", control: makePopUp(titles: Self.themeTitles, selectedIndex: themeIndex) { [weak self] index in
                guard let self, Self.themeOrder.indices.contains(index) else { return }
                viewModel.selectedTheme = Self.themeOrder[index]
            })
        ])

        let dateIndex = Self.dateOrder.firstIndex(of: viewModel.selectedDateFormat) ?? 0
        let timeIndex = Self.timeOrder.firstIndex(of: viewModel.selectedTimeFormat) ?? 0
        let numberIndex = Self.numberOrder.firstIndex(of: viewModel.selectedNumberFormat) ?? 0
        addSection("Formatting", views: [
            labeledRow("Date format", control: makePopUp(titles: Self.dateTitles, selectedIndex: dateIndex) { [weak self] index in
                guard let self, Self.dateOrder.indices.contains(index) else { return }
                viewModel.selectedDateFormat = Self.dateOrder[index]
            }),
            labeledRow("Time format", control: makePopUp(titles: Self.timeTitles, selectedIndex: timeIndex) { [weak self] index in
                guard let self, Self.timeOrder.indices.contains(index) else { return }
                viewModel.selectedTimeFormat = Self.timeOrder[index]
            }),
            labeledRow("Number format", control: makePopUp(titles: Self.numberTitles, selectedIndex: numberIndex) { [weak self] index in
                guard let self, Self.numberOrder.indices.contains(index) else { return }
                viewModel.selectedNumberFormat = Self.numberOrder[index]
            }),
            makeCheckbox("Prefer absolute dates over relative", isOn: viewModel.preferAbsoluteDates) { [weak self] in
                self?.viewModel.preferAbsoluteDates = $0
            }
        ])

        let tabSizes = viewModel.availableTabSizes
        let tabIndex = tabSizes.firstIndex(of: viewModel.selectedTabSize) ?? 0
        addSection("Diff", views: [
            labeledRow("Tab size", control: makePopUp(titles: tabSizes.map(String.init), selectedIndex: tabIndex, width: 80) { [weak self] index in
                guard let self, tabSizes.indices.contains(index) else { return }
                viewModel.selectedTabSize = tabSizes[index]
            })
        ])
    }
}
