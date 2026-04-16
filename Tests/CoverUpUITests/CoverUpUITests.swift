import XCTest

final class CoverUpUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app.terminate()
        app = nil
        super.tearDown()
    }

    /// Verify the app launches and is running without crashing.
    func testAppLaunchesWithoutCrash() {
        app.launch()
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground,
            "App must be running after launch")
    }
}
