import AppKit

/// Hosts and renders all active MaskRegion rectangles.
/// Regions are injected by MaskRegionManager (added in Task-003).
class OverlayView: NSView {

    /// Called by the tracker/manager when regions change.
    var onNeedsRedraw: (() -> Void)?

    override var isFlipped: Bool { return false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Regions will be drawn here once MaskRegionManager is available (Task-003/005).
        // For now, clear the view.
        NSColor.clear.set()
        dirtyRect.fill()
    }

    /// Trigger a redraw on the main thread.
    func scheduleRedraw() {
        DispatchQueue.main.async { [weak self] in
            self?.needsDisplay = true
        }
    }
}
