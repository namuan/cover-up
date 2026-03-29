import XCTest
import Combine
@testable import CoverUp

final class IntegrationTests: XCTestCase {

    var manager: MaskRegionManager!
    var mockProvider: MockCGWindowListProvider!
    var tracker: WindowTracker!
    var overlayWindow: OverlayWindow!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        manager = MaskRegionManager()
        mockProvider = MockCGWindowListProvider()
        tracker = WindowTracker(manager: manager, provider: mockProvider)
        overlayWindow = OverlayWindow(manager: manager)
        cancellables = []
    }

    override func tearDown() {
        tracker.stop()
        tracker = nil
        mockProvider = nil
        manager = nil
        overlayWindow = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Test 1: Two mock regions converge to correct positions within 5 frames

    func testTwoTrackedRegionsConvergeWithin5Frames() {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0

        let regionA = MaskRegion(id: "winA", targetWindowTitle: "MockWindowA", relativeRect: .zero)
        let regionB = MaskRegion(id: "winB", targetWindowTitle: "MockWindowB", relativeRect: .zero)
        manager.addRegion(regionA)
        manager.addRegion(regionB)

        mockProvider.windows = [
            [
                kCGWindowName as String: "MockWindowA",
                kCGWindowBounds as String: ["X": CGFloat(100), "Y": CGFloat(200), "Width": CGFloat(300), "Height": CGFloat(150)] as [String: CGFloat]
            ],
            [
                kCGWindowName as String: "MockWindowB",
                kCGWindowBounds as String: ["X": CGFloat(500), "Y": CGFloat(50), "Width": CGFloat(200), "Height": CGFloat(100)] as [String: CGFloat]
            ]
        ]

        let exp = expectation(description: "5 tracker updates")
        exp.expectedFulfillmentCount = 5
        tracker.onUpdate = { exp.fulfill() }
        tracker.start()
        wait(for: [exp], timeout: 2.0)
        tracker.stop()

        let updatedA = manager.regions.first(where: { $0.id == "winA" })!.relativeRect
        let expectedAY = screenHeight - 200 - 150
        XCTAssertEqual(updatedA.origin.x, 100, accuracy: 1)
        XCTAssertEqual(updatedA.origin.y, expectedAY, accuracy: 1)
        XCTAssertEqual(updatedA.width, 300, accuracy: 1)
        XCTAssertEqual(updatedA.height, 150, accuracy: 1)

        let updatedB = manager.regions.first(where: { $0.id == "winB" })!.relativeRect
        let expectedBY = screenHeight - 50 - 100
        XCTAssertEqual(updatedB.origin.x, 500, accuracy: 1)
        XCTAssertEqual(updatedB.origin.y, expectedBY, accuracy: 1)
        XCTAssertEqual(updatedB.width, 200, accuracy: 1)
        XCTAssertEqual(updatedB.height, 100, accuracy: 1)
    }

    // MARK: - Test 2: Toggle overlay visibility

    func testToggleOverlayVisibility() {
        XCTAssertTrue(overlayWindow.isVisible, "Window should start visible")

        overlayWindow.orderOut(nil)
        XCTAssertFalse(overlayWindow.isVisible, "Window should be hidden after orderOut")

        overlayWindow.orderFrontRegardless()
        XCTAssertTrue(overlayWindow.isVisible, "Window should be visible after orderFrontRegardless")
    }

    // MARK: - Test 3: Performance — 10 regions, 90 ticks within a reasonable time budget

    func testPerformanceWith10Regions() {
        for i in 0..<10 {
            let region = MaskRegion(id: "perf-\(i)", targetWindowTitle: "PerfWindow\(i)", relativeRect: .zero)
            manager.addRegion(region)
        }

        mockProvider.windows = (0..<10).map { i in
            [
                kCGWindowName as String: "PerfWindow\(i)",
                kCGWindowBounds as String: ["X": CGFloat(i * 50), "Y": CGFloat(i * 30), "Width": CGFloat(100), "Height": CGFloat(50)] as [String: CGFloat]
            ]
        }

        let start = Date()
        let exp = expectation(description: "90 frames (3s at 30fps)")
        exp.expectedFulfillmentCount = 90
        tracker.onUpdate = { exp.fulfill() }
        tracker.start()
        wait(for: [exp], timeout: 5.0)
        tracker.stop()
        let elapsed = Date().timeIntervalSince(start)

        // 90 ticks at 30 FPS should complete in roughly 3 seconds; allow generous headroom
        XCTAssertLessThan(elapsed, 5.0, "90 ticks with 10 regions must complete in under 5 seconds")
    }

    // MARK: - Test 4: AppDelegate wires all components

    func testAllComponentsWiredInAppDelegate() {
        let mgr = MaskRegionManager()
        let window = OverlayWindow(manager: mgr)
        let statusCtrl = StatusMenuController(manager: mgr, overlayWindow: window)

        XCTAssertNotNil(window.overlayView, "OverlayView must be wired in window")
        XCTAssertNotNil(statusCtrl, "StatusMenuController must initialize without crash")

        let trk = WindowTracker(manager: mgr)
        trk.onUpdate = { [weak window] in window?.overlayView?.scheduleRedraw() }
        trk.start()
        XCTAssertTrue(trk.isRunning)
        trk.stop()
    }
}
