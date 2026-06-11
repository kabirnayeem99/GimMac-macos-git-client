import Foundation

/// Bundle of settings dependencies assembled at the composition root and handed
/// to the Settings window so each pane can build its ViewModel. Keeps
/// `AppDelegate` wiring in one place and the window controller free of concrete
/// service construction.
@MainActor
struct SettingsEnvironment {
    let settingsStore: any AppSettingsStoring
    let configReader: any GitConfigReading
    let configWriter: any GitConfigWriting
    let editorService: any ExternalEditorServiceProtocol
    let shellService: any ShellServiceProtocol
    let themeApplier: any ThemeApplying
    let notificationAuthorizer: any NotificationAuthorizing

    func makeGitViewModel() -> GitSettingsViewModel {
        GitSettingsViewModel(configReader: configReader, configWriter: configWriter)
    }

    func makeIntegrationsViewModel() -> IntegrationsSettingsViewModel {
        IntegrationsSettingsViewModel(
            store: settingsStore,
            editorService: editorService,
            shellService: shellService
        )
    }

    func makeAppearanceViewModel() -> AppearanceSettingsViewModel {
        AppearanceSettingsViewModel(store: settingsStore, themeApplier: themeApplier)
    }

    func makeNotificationsViewModel() -> NotificationsSettingsViewModel {
        NotificationsSettingsViewModel(store: settingsStore, authorizer: notificationAuthorizer)
    }

    func makePromptsViewModel() -> PromptsSettingsViewModel {
        PromptsSettingsViewModel(store: settingsStore)
    }

    func makeAdvancedViewModel() -> AdvancedSettingsViewModel {
        AdvancedSettingsViewModel(store: settingsStore)
    }

    func makeAccessibilityViewModel() -> AccessibilitySettingsViewModel {
        AccessibilitySettingsViewModel(store: settingsStore)
    }
}
