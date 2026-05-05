import XCTest

@MainActor
final class GimMacUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
