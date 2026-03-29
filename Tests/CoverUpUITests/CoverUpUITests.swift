import XCTest

final class CoverUpUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--add-test-region", "--open-control-panel"]
    }

    override func tearDown() {
        app.terminate()
        app = nil
        super.tearDown()
    }

    /// Launch the app with a pre-seeded region and auto-opened control panel.
    /// Assert: the control panel window appears and contains at least one region row.
    func testControlPanelShowsRegionRow() {
        app.launch()

        // Wait for the control panel window to appear (it opens after 0.5s delay)
        let panel = app.windows["CoverUp \u{2014} Regions"]
        let panelExists = panel.waitForExistence(timeout: 5.0)
        XCTAssertTrue(panelExists, "Control panel window must appear after launch with --open-control-panel")

        // The RegionListController adds checkboxes for each region.
        let checkboxes = panel.checkBoxes
        XCTAssertGreaterThan(checkboxes.count, 0,
            "Control panel must show at least one region row (checkbox) for the pre-seeded region")
    }

    /// Verify the app launches and is running without crashing.
    func testAppLaunchesWithoutCrash() {
        app.launch()
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground,
            "App must be running after launch")
    }
}
