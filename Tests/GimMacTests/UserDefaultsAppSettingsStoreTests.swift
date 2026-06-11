import XCTest
@testable import GimMac

final class UserDefaultsAppSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsAppSettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "io.github.kabirnayeem99.gimmac.tests.settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = UserDefaultsAppSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsMatchGitHubDesktop() {
        XCTAssertTrue(store.confirmDiscardChanges)
        XCTAssertTrue(store.confirmForcePush)
        XCTAssertTrue(store.confirmRepositoryRemoval)
        XCTAssertTrue(store.showCommitLengthWarning)
        XCTAssertTrue(store.repositoryIndicatorsEnabled)
        XCTAssertTrue(store.notificationsEnabled)
        XCTAssertTrue(store.underlineLinks)
        XCTAssertTrue(store.showDiffCheckMarks)
        XCTAssertFalse(store.useExternalCredentialHelper)
        XCTAssertFalse(store.preferAbsoluteDates)
        XCTAssertEqual(store.selectedTheme, .system)
        XCTAssertEqual(store.selectedTabSize, 4)
        XCTAssertEqual(store.uncommittedChangesStrategy, .askForConfirmation)
        XCTAssertEqual(store.selectedDateFormat, .localeDefault)
    }

    func testBooleanRoundTrip() {
        store.confirmForcePush = false
        XCTAssertFalse(store.confirmForcePush)
        // A fresh store over the same defaults reads the persisted value.
        let reopened = UserDefaultsAppSettingsStore(defaults: defaults)
        XCTAssertFalse(reopened.confirmForcePush)
    }

    func testEnumRoundTrip() {
        store.selectedTheme = .dark
        store.uncommittedChangesStrategy = .stashOnCurrentBranch
        let reopened = UserDefaultsAppSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.selectedTheme, .dark)
        XCTAssertEqual(reopened.uncommittedChangesStrategy, .stashOnCurrentBranch)
    }

    func testTabSizeIsClamped() {
        store.selectedTabSize = 99
        XCTAssertEqual(store.selectedTabSize, 12)
        store.selectedTabSize = 0
        XCTAssertEqual(store.selectedTabSize, 1)
    }

    func testCustomIntegrationRoundTrip() {
        store.customEditor = CustomIntegration(path: "/usr/bin/vi", bundleID: "org.vim", arguments: "--wait %TARGET_PATH%")
        let reopened = UserDefaultsAppSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.customEditor.path, "/usr/bin/vi")
        XCTAssertEqual(reopened.customEditor.bundleID, "org.vim")
        XCTAssertEqual(reopened.customEditor.arguments, "--wait %TARGET_PATH%")
    }

    func testExternalEditorBundleIDReusesLegacyKey() {
        store.selectedExternalEditorBundleID = "com.microsoft.VSCode"
        XCTAssertEqual(
            defaults.string(forKey: ExternalEditorPreferences.selectedEditorKey),
            "com.microsoft.VSCode"
        )
    }
}
