import XCTest

@MainActor
final class GimMacUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testGitProcessFailureAppearsInStatusLabel() {
        let app = XCUIApplication()
        app.launchEnvironment["GIMMAC_UI_TEST_REPO_PATH"] = "/path/that/does/not/exist"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let statusLabel = app.staticTexts["statusLabel"]
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 10))
    }
}
