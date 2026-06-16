import Foundation
import Observation

/// Drives the Accessibility pane of Settings: underlining links and showing
/// check marks beside diff line numbers. Native equivalent of GitHub Desktop's
/// `Accessibility` preferences panel (`ui/preferences/accessibility.tsx`).
@MainActor
@Observable
final class AccessibilitySettingsViewModel {
    var underlineLinks: Bool { didSet { store.underlineLinks = underlineLinks } }
    var showDiffCheckMarks: Bool { didSet { store.showDiffCheckMarks = showDiffCheckMarks } }

    private let store: any AppSettingsStoring

    init(store: any AppSettingsStoring) {
        self.store = store
        underlineLinks = store.underlineLinks
        showDiffCheckMarks = store.showDiffCheckMarks
    }
}
