import XCTest
@testable import CoverUp

// MARK: - Mock provider

final class MockCGWindowListProvider: CGWindowListProvider {
    var windows: [[String: Any]] = []

    func windowList() -> [[String: Any]] {
        return windows
    }

    func setWindow(name: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        windows = [[
            kCGWindowName as String: name,
            kCGWindowBounds as String: [
                "X": x, "Y": y, "Width": width, "Height": height
            ] as [String: CGFloat]
        ]]
    }
}

// MARK: - Tests

final class WindowTrackerTests: XCTestCase {

    var manager: MaskRegionManager!
    var mockProvider: MockCGWindowListProvider!
    var tracker: WindowTracker!

    override func setUp() {
        super.setUp()
        manager = MaskRegionManager()
        mockProvider = MockCGWindowListProvider()
        tracker = WindowTracker(manager: manager, provider: mockProvider)
    }

    override func tearDown() {
        tracker.stop()
        tracker = nil
        mockProvider = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - Coordinate conversion

    func testConvertToAppKitFlipsY() {
        // Primary screen height — use first screen or fall back to 800 for headless
        let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0
        // CGWindow rect: top-left at (100, 50), 200 wide, 80 tall
        let cgRect = CGRect(x: 100, y: 50, width: 200, height: 80)
        let result = tracker.convertToAppKit(cgWindowBounds: cgRect)
        // Expected AppKit Y = screenHeight - 50 - 80
        let expectedY = screenHeight - 50 - 80
        XCTAssertEqual(result.origin.x, 100)
        XCTAssertEqual(result.origin.y, expectedY)
        XCTAssertEqual(result.width, 200)
        XCTAssertEqual(result.height, 80)
    }

    func testConvertToAppKitAtOrigin() {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0
        let cgRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let result = tracker.convertToAppKit(cgWindowBounds: cgRect)
        // Window at top-left → AppKit y = screenHeight - 0 - 100
        XCTAssertEqual(result.origin.y, screenHeight - 100)
    }

    // MARK: - Static region is not updated

    func testStaticRegionIsNotUpdated() {
        let originalRect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let region = MaskRegion(id: "static", targetWindowTitle: nil, relativeRect: originalRect)
        manager.addRegion(region)

        mockProvider.setWindow(name: "Anything", x: 0, y: 0, width: 500, height: 500)

        // Manually invoke tick by starting then immediately stopping
        let exp = expectation(description: "onUpdate fires")
        tracker.onUpdate = { exp.fulfill() }
        tracker.start()
        wait(for: [exp], timeout: 1.0)
        tracker.stop()

        XCTAssertEqual(manager.regions.first?.relativeRect, originalRect,
            "Static region must not be moved by tracker")
    }

    // MARK: - Window-tracking region is updated

    func testTrackedRegionUpdatesRect() {
        let region = MaskRegion(id: "tracked", targetWindowTitle: "TestApp", relativeRect: .zero)
        manager.addRegion(region)

        let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0
        mockProvider.setWindow(name: "TestApp", x: 50, y: 100, width: 300, height: 200)

        let exp = expectation(description: "onUpdate fires")
        tracker.onUpdate = { exp.fulfill() }
        tracker.start()
        wait(for: [exp], timeout: 1.0)
        tracker.stop()

        let updatedRect = manager.regions.first!.relativeRect
        let expectedY = screenHeight - 100 - 200
        XCTAssertEqual(updatedRect.origin.x, 50)
        XCTAssertEqual(updatedRect.origin.y, expectedY)
        XCTAssertEqual(updatedRect.width, 300)
        XCTAssertEqual(updatedRect.height, 200)
    }

    func testTrackedSubregionPreservesOffsetAndSize() {
        let region = MaskRegion(
            id: "tracked-subregion",
            targetWindowTitle: "TestApp",
            trackedWindowLocalRect: CGRect(x: 25, y: 30, width: 120, height: 45),
            relativeRect: .zero
        )
        manager.addRegion(region)

        let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0
        mockProvider.setWindow(name: "TestApp", x: 50, y: 100, width: 300, height: 200)

        let exp = expectation(description: "onUpdate fires")
        tracker.onUpdate = { exp.fulfill() }
        tracker.start()
        wait(for: [exp], timeout: 1.0)
        tracker.stop()

        let updatedRect = manager.regions.first!.relativeRect
        let expectedWindowY = screenHeight - 100 - 200
        XCTAssertEqual(updatedRect.origin.x, 75)
        XCTAssertEqual(updatedRect.origin.y, expectedWindowY + 30)
        XCTAssertEqual(updatedRect.width, 120)
        XCTAssertEqual(updatedRect.height, 45)
    }

    // MARK: - Case-insensitive matching

    func testCaseInsensitiveWindowMatch() {
        let region = MaskRegion(id: "r1", targetWindowTitle: "testapp", relativeRect: .zero)
        manager.addRegion(region)

        let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0
        mockProvider.setWindow(name: "TestApp", x: 0, y: 0, width: 100, height: 100)

        let exp = expectation(description: "track")
        tracker.onUpdate = { exp.fulfill() }
        tracker.start()
        wait(for: [exp], timeout: 1.0)
        tracker.stop()

        let updatedRect = manager.regions.first!.relativeRect
        XCTAssertEqual(updatedRect.width, 100, "Case-insensitive match should update the region")
    }

    // MARK: - Start/stop

    func testStartSetsIsRunning() {
        XCTAssertFalse(tracker.isRunning)
        tracker.start()
        XCTAssertTrue(tracker.isRunning)
        tracker.stop()
        XCTAssertFalse(tracker.isRunning)
    }

    func testDoubleStartIsIdempotent() {
        tracker.start()
        tracker.start() // should not crash or create extra timers
        XCTAssertTrue(tracker.isRunning)
        tracker.stop()
    }
}
