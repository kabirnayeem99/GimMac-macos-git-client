import Foundation
import Observation

/// Drives the Advanced pane of Settings: background repository indicators and
/// the external Git credential helper. Native equivalent of the Git-relevant
/// rows in GitHub Desktop's `Advanced` preferences panel
/// (`ui/preferences/advanced.tsx`) — usage-stats telemetry and Windows OpenSSH
/// are intentionally excluded.
@MainActor
@Observable
final class AdvancedSettingsViewModel {
    var repositoryIndicatorsEnabled: Bool {
        didSet { store.repositoryIndicatorsEnabled = repositoryIndicatorsEnabled }
    }
    var useExternalCredentialHelper: Bool {
        didSet { store.useExternalCredentialHelper = useExternalCredentialHelper }
    }

    private let store: any AppSettingsStoring

    init(store: any AppSettingsStoring) {
        self.store = store
        repositoryIndicatorsEnabled = store.repositoryIndicatorsEnabled
        useExternalCredentialHelper = store.useExternalCredentialHelper
    }
}
