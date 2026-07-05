import XCTest
@testable import GimMac

// MARK: - Fakes

/// In-memory `AppSettingsStoring` for ViewModel tests. Mutated only from the
/// main actor in tests, hence `@unchecked Sendable`.
private final class FakeAppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    var confirmRepositoryRemoval = true
    var confirmDiscardChanges = true
    var confirmDiscardChangesPermanently = true
    var confirmDiscardStash = true
    var confirmCheckoutCommit = true
    var confirmForcePush = true
    var confirmUndoCommit = true
    var confirmCommitFilteredChanges = true
    var uncommittedChangesStrategy: UncommittedChangesStrategy = .askForConfirmation
    var showCommitLengthWarning = true
    var selectedTheme: ApplicationTheme = .system
    var selectedTabSize = 4
    var selectedDateFormat: DateFormat = .localeDefault
    var selectedTimeFormat: TimeFormat = .localeDefault
    var selectedNumberFormat: NumberFormat = .localeDefault
    var preferAbsoluteDates = false
    var selectedExternalEditorBundleID: String?
    var useCustomEditor = false
    var customEditor = CustomIntegration()
    var selectedShellBundleID: String?
    var useCustomShell = false
    var customShell = CustomIntegration()
    var repositoryIndicatorsEnabled = true
    var useExternalCredentialHelper = false
    var notificationsEnabled = true
    var underlineLinks = true
    var showDiffCheckMarks = true
    var onboardingCompleted = false
}

private actor FakeGitConfig: GitConfigReading, GitConfigWriting {
    var name: String?
    var email: String?
    var defaultBranch: String?
    private(set) var writes: [String: String] = [:]

    init(name: String? = nil, email: String? = nil, defaultBranch: String? = nil) {
        self.name = name
        self.email = email
        self.defaultBranch = defaultBranch
    }

    func globalUserName() async throws -> String? { name }
    func globalUserEmail() async throws -> String? { email }
    func globalDefaultBranch() async throws -> String? { defaultBranch }
    func setGlobalUserName(_ name: String) async throws { self.name = name; writes["user.name"] = name }
    func setGlobalUserEmail(_ email: String) async throws { self.email = email; writes["user.email"] = email }
    func setGlobalDefaultBranch(_ branch: String) async throws {
        defaultBranch = branch; writes["init.defaultBranch"] = branch
    }

    func recordedWrites() -> [String: String] { writes }
}

@MainActor
private final class SpyThemeApplier: ThemeApplying {
    private(set) var applied: [ApplicationTheme] = []
    func apply(_ theme: ApplicationTheme) { applied.append(theme) }
}

private final class FakeNotificationAuthorizer: NotificationAuthorizing, @unchecked Sendable {
    var status: NotificationAuthorizationStatus
    private(set) var requestCount = 0
    init(status: NotificationAuthorizationStatus) { self.status = status }
    func authorizationStatus() async -> NotificationAuthorizationStatus { status }
    func requestAuthorization() async -> NotificationAuthorizationStatus {
        requestCount += 1
        status = .authorized
        return status
    }
}

@MainActor
private final class FakeEditorService: ExternalEditorServiceProtocol {
    var editors: [ExternalEditor]
    init(editors: [ExternalEditor]) { self.editors = editors }
    func availableEditors() -> [ExternalEditor] { editors }
    func launch(editor: ExternalEditor, at repositoryURL: URL) {}
}

@MainActor
private final class FakeShellService: ShellServiceProtocol {
    var shells: [TerminalShell]
    init(shells: [TerminalShell]) { self.shells = shells }
    func availableShells() -> [TerminalShell] { shells }
    func launch(shell: TerminalShell, at repositoryURL: URL) {}
}

private func makeEditor(_ name: String, _ bundleID: String) -> ExternalEditor {
    ExternalEditor(name: name, bundleIdentifier: bundleID, appURL: URL(fileURLWithPath: "/Applications/\(name).app"))
}

private func makeShell(_ name: String, _ bundleID: String) -> TerminalShell {
    TerminalShell(name: name, bundleIdentifier: bundleID, appURL: URL(fileURLWithPath: "/Applications/\(name).app"))
}

// MARK: - Tests

@MainActor
final class SettingsViewModelTests: XCTestCase {

    // GitSettingsViewModel

    func testGitSettingsLoadsExistingConfig() async {
        let config = FakeGitConfig(name: "Ada", email: "ada@example.com", defaultBranch: "main")
        let vm = GitSettingsViewModel(configReader: config, configWriter: config)
        await vm.load()
        XCTAssertEqual(vm.committerName, "Ada")
        XCTAssertEqual(vm.committerEmail, "ada@example.com")
        XCTAssertEqual(vm.defaultBranch, "main")
    }

    func testGitSettingsSavesOnlyChangedFields() async {
        let config = FakeGitConfig(name: "Ada", email: "ada@example.com", defaultBranch: "main")
        let vm = GitSettingsViewModel(configReader: config, configWriter: config)
        await vm.load()
        vm.committerName = "Grace"
        await vm.save()
        let writes = await config.recordedWrites()
        XCTAssertEqual(writes["user.name"], "Grace")
        XCTAssertNil(writes["user.email"], "Unchanged email should not be written")
        XCTAssertNil(writes["init.defaultBranch"], "Unchanged branch should not be written")
    }

    func testGitSettingsDoesNotWriteEmptyDefaultBranch() async {
        let config = FakeGitConfig(name: "Ada", email: "ada@example.com", defaultBranch: "main")
        let vm = GitSettingsViewModel(configReader: config, configWriter: config)
        await vm.load()
        vm.defaultBranch = ""
        await vm.save()
        let writes = await config.recordedWrites()
        XCTAssertNil(writes["init.defaultBranch"])
    }

    func testGitSettingsNameValidation() {
        XCTAssertTrue(GitSettingsViewModel.isAuthorNameValid("Ada Lovelace"))
        XCTAssertTrue(GitSettingsViewModel.isAuthorNameValid(""))
        XCTAssertFalse(GitSettingsViewModel.isAuthorNameValid("<>"))
    }

    // PromptsSettingsViewModel

    func testPromptsWriteThroughToStore() {
        let store = FakeAppSettingsStore()
        let vm = PromptsSettingsViewModel(store: store)
        vm.confirmForcePush = false
        vm.uncommittedChangesStrategy = .stashOnCurrentBranch
        XCTAssertFalse(store.confirmForcePush)
        XCTAssertEqual(store.uncommittedChangesStrategy, .stashOnCurrentBranch)
    }

    func testPromptsInitReflectsStore() {
        let store = FakeAppSettingsStore()
        store.confirmDiscardStash = false
        let vm = PromptsSettingsViewModel(store: store)
        XCTAssertFalse(vm.confirmDiscardStash)
    }

    // AppearanceSettingsViewModel

    func testAppearanceAppliesThemeOnChange() {
        let store = FakeAppSettingsStore()
        let spy = SpyThemeApplier()
        let vm = AppearanceSettingsViewModel(store: store, themeApplier: spy)
        vm.selectedTheme = .dark
        XCTAssertEqual(store.selectedTheme, .dark)
        XCTAssertEqual(spy.applied, [.dark])
    }

    func testAppearanceTabSizeWriteThrough() {
        let store = FakeAppSettingsStore()
        let vm = AppearanceSettingsViewModel(store: store, themeApplier: SpyThemeApplier())
        vm.selectedTabSize = 8
        XCTAssertEqual(store.selectedTabSize, 8)
    }

    // AdvancedSettingsViewModel + AccessibilitySettingsViewModel

    func testAdvancedWriteThrough() {
        let store = FakeAppSettingsStore()
        let vm = AdvancedSettingsViewModel(store: store)
        vm.useExternalCredentialHelper = true
        vm.repositoryIndicatorsEnabled = false
        XCTAssertTrue(store.useExternalCredentialHelper)
        XCTAssertFalse(store.repositoryIndicatorsEnabled)
    }

    func testAccessibilityWriteThrough() {
        let store = FakeAppSettingsStore()
        let vm = AccessibilitySettingsViewModel(store: store)
        vm.underlineLinks = false
        XCTAssertFalse(store.underlineLinks)
    }

    // NotificationsSettingsViewModel

    func testNotificationsRefreshAndRequest() async {
        let store = FakeAppSettingsStore()
        let authorizer = FakeNotificationAuthorizer(status: .notDetermined)
        let vm = NotificationsSettingsViewModel(store: store, authorizer: authorizer)
        await vm.refreshPermissionStatus()
        XCTAssertEqual(vm.permissionStatus, .notDetermined)
        await vm.requestPermission()
        XCTAssertEqual(vm.permissionStatus, .authorized)
        XCTAssertEqual(authorizer.requestCount, 1)
    }

    func testNotificationsToggleWriteThrough() {
        let store = FakeAppSettingsStore()
        let vm = NotificationsSettingsViewModel(
            store: store,
            authorizer: FakeNotificationAuthorizer(status: .authorized)
        )
        vm.notificationsEnabled = false
        XCTAssertFalse(store.notificationsEnabled)
    }

    // IntegrationsSettingsViewModel

    private func makeIntegrationsVM(
        store: FakeAppSettingsStore,
        editors: [ExternalEditor],
        shells: [TerminalShell]
    ) -> IntegrationsSettingsViewModel {
        IntegrationsSettingsViewModel(
            store: store,
            editorService: FakeEditorService(editors: editors),
            shellService: FakeShellService(shells: shells)
        )
    }

    func testIntegrationsReloadPopulatesLists() {
        let store = FakeAppSettingsStore()
        let vm = makeIntegrationsVM(
            store: store,
            editors: [makeEditor("Zed", "dev.zed.Zed")],
            shells: [makeShell("Terminal", "com.apple.Terminal")]
        )
        vm.reloadAvailableIntegrations()
        XCTAssertEqual(vm.availableEditors.count, 1)
        XCTAssertEqual(vm.availableShells.count, 1)
    }

    func testIntegrationsFallsBackToFirstWhenSelectionMissing() {
        let store = FakeAppSettingsStore()
        store.selectedExternalEditorBundleID = "com.unknown.editor"
        let vm = makeIntegrationsVM(
            store: store,
            editors: [makeEditor("Zed", "dev.zed.Zed")],
            shells: [makeShell("Terminal", "com.apple.Terminal")]
        )
        vm.reloadAvailableIntegrations()
        XCTAssertEqual(vm.selectedEditorBundleID, "dev.zed.Zed")
        XCTAssertEqual(store.selectedExternalEditorBundleID, "dev.zed.Zed")
        XCTAssertEqual(vm.selectedShellBundleID, "com.apple.Terminal")
    }

    func testIntegrationsKeepsValidStoredSelection() {
        let store = FakeAppSettingsStore()
        store.selectedExternalEditorBundleID = "dev.zed.Zed"
        let vm = makeIntegrationsVM(
            store: store,
            editors: [makeEditor("Cursor", "com.cursor"), makeEditor("Zed", "dev.zed.Zed")],
            shells: []
        )
        vm.reloadAvailableIntegrations()
        XCTAssertEqual(vm.selectedEditorBundleID, "dev.zed.Zed")
    }

    func testIntegrationsDoesNotOverrideWhenUsingCustom() {
        let store = FakeAppSettingsStore()
        store.useCustomEditor = true
        let vm = makeIntegrationsVM(
            store: store,
            editors: [makeEditor("Zed", "dev.zed.Zed")],
            shells: []
        )
        vm.reloadAvailableIntegrations()
        XCTAssertNil(vm.selectedEditorBundleID, "Custom editor selection should not auto-pick an installed editor")
    }

    func testIntegrationsCustomEditorWriteThrough() {
        let store = FakeAppSettingsStore()
        let vm = makeIntegrationsVM(store: store, editors: [], shells: [])
        vm.customEditor = CustomIntegration(path: "/bin/ed", bundleID: nil, arguments: "%TARGET_PATH%")
        XCTAssertEqual(store.customEditor.path, "/bin/ed")
    }
}
