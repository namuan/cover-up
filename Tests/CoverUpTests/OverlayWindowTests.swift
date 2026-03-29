import XCTest
@testable import CoverUp

final class OverlayWindowTests: XCTestCase {

    var window: OverlayWindow!

    override func setUp() {
        super.setUp()
        window = OverlayWindow()
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    func testWindowLevel() {
        XCTAssertEqual(window.level, .screenSaver,
            "Overlay must float above all app windows")
    }

    func testTransparency() {
        XCTAssertFalse(window.isOpaque, "Overlay window must be non-opaque")
        XCTAssertEqual(window.backgroundColor, .clear, "Background must be clear")
    }

    func testClickThrough() {
        XCTAssertTrue(window.ignoresMouseEvents,
            "Overlay must be click-through")
    }

    func testBorderless() {
        XCTAssertEqual(window.styleMask, .borderless,
            "Overlay must have no chrome")
    }

    func testContentViewIsOverlayView() {
        XCTAssertNotNil(window.overlayView,
            "Content view must be an OverlayView instance")
    }

    func testFrameSpansScreens() {
        let expected = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        XCTAssertEqual(window.frame, expected,
            "Overlay must span all connected screens")
    }
}
