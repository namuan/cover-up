import XCTest
import AppKit
@testable import CoverUp

final class OverlayViewTests: XCTestCase {

    // MARK: - Helpers

    /// Render the view off-screen and return a bitmap for pixel inspection.
    private func renderOffScreen(view: OverlayView, size: NSSize) -> NSBitmapImageRep? {
        view.frame = NSRect(origin: .zero, size: size)

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            XCTFail("Could not create bitmap rep")
            return nil
        }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    /// Get colour of pixel at (x, y) in the rep. Y=0 is the top of the bitmap.
    private func pixel(at point: NSPoint, in rep: NSBitmapImageRep) -> NSColor? {
        return rep.colorAt(x: Int(point.x), y: Int(point.y))
    }

    // MARK: - Tests

    func testActiveRegionDrawnAsBlack() {
        let manager = MaskRegionManager()
        let view = OverlayView(frame: .zero)
        view.manager = manager

        // Add a region occupying the top-left 100×100 area.
        // In AppKit coordinates (bottom-left origin), y=100 in a 200-pt-tall view
        // means the rect sits at the bottom half. For off-screen bitmap, row 0
        // is the bottom in AppKit but in NSBitmapImageRep row 0 is top.
        // We keep it simple: use a large rect that covers the whole view.
        let region = MaskRegion(
            id: "test-black",
            relativeRect: CGRect(x: 0, y: 0, width: 200, height: 200),
            isActive: true
        )
        manager.addRegion(region)

        guard let rep = renderOffScreen(view: view, size: NSSize(width: 200, height: 200)) else { return }

        // Sample center pixel — must be black (alpha = 1)
        if let color = pixel(at: NSPoint(x: 100, y: 100), in: rep)?.usingColorSpace(.deviceRGB) {
            XCTAssertEqual(color.redComponent, 0.0, accuracy: 0.05, "Red must be 0 for black region")
            XCTAssertEqual(color.greenComponent, 0.0, accuracy: 0.05, "Green must be 0 for black region")
            XCTAssertEqual(color.blueComponent, 0.0, accuracy: 0.05, "Blue must be 0 for black region")
            XCTAssertGreaterThan(color.alphaComponent, 0.9, "Alpha must be opaque for black region")
        } else {
            XCTFail("Could not read pixel color")
        }
    }

    func testInactiveRegionNotDrawn() {
        let manager = MaskRegionManager()
        let view = OverlayView(frame: .zero)
        view.manager = manager

        let region = MaskRegion(
            id: "inactive",
            relativeRect: CGRect(x: 0, y: 0, width: 200, height: 200),
            isActive: false
        )
        manager.addRegion(region)

        guard let rep = renderOffScreen(view: view, size: NSSize(width: 200, height: 200)) else { return }

        // Center pixel must be transparent (alpha = 0) since region is inactive
        if let color = pixel(at: NSPoint(x: 100, y: 100), in: rep)?.usingColorSpace(.deviceRGB) {
            XCTAssertEqual(color.alphaComponent, 0.0, accuracy: 0.05,
                "Inactive region pixel must be transparent")
        } else {
            XCTFail("Could not read pixel color")
        }
    }

    func testPixelOutsideRegionIsTransparent() {
        let manager = MaskRegionManager()
        let view = OverlayView(frame: .zero)
        view.manager = manager

        // Region only covers x: 0-100, y: 0-100 in a 200x200 view
        let region = MaskRegion(
            id: "small",
            relativeRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            isActive: true
        )
        manager.addRegion(region)

        guard let rep = renderOffScreen(view: view, size: NSSize(width: 200, height: 200)) else { return }

        // Pixel at (150, 150) is outside the region — must be transparent
        // In NSBitmapImageRep, row 0 is at top. (150, 150) in rep coords
        // corresponds to AppKit y = 200 - 150 = 50, which is inside the region.
        // So use (150, 50) in rep coords → AppKit y = 200-50 = 150, outside region.
        if let color = pixel(at: NSPoint(x: 150, y: 50), in: rep)?.usingColorSpace(.deviceRGB) {
            XCTAssertEqual(color.alphaComponent, 0.0, accuracy: 0.05,
                "Pixel outside region must be transparent")
        } else {
            XCTFail("Could not read pixel color")
        }
    }

    func testNeedsDisplayOnRegionUpdate() {
        let manager = MaskRegionManager()
        let view = OverlayView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        view.manager = manager

        // Reset needsDisplay
        view.needsDisplay = false

        // Adding a region should trigger needsDisplay via Combine subscription
        manager.addRegion(MaskRegion(id: "trigger"))

        // Give the runloop a tick to dispatch the main-queue update
        let exp = expectation(description: "needsDisplay set")
        DispatchQueue.main.async {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(view.needsDisplay, "Adding a region must mark view for redraw")
    }
}
