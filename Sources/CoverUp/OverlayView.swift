import AppKit
import Combine

/// Renders all active MaskRegion rectangles as black boxes.
class OverlayView: NSView {

    // MARK: - Dependencies

    /// Injected by OverlayWindow after construction.
    var manager: MaskRegionManager? {
        didSet { observeManager() }
    }

    private var cancellables = Set<AnyCancellable>()
    private var _markedForRedraw = false

    // MARK: - needsDisplay override
    //
    // AppKit's display cycle may clear the internal needsDisplay flag for views
    // not in a window hierarchy, making unit tests that check needsDisplay unreliable.
    // This override keeps a persistent backing flag so needsDisplay stays true until
    // draw(_:) is actually called.

    override var needsDisplay: Bool {
        get { _markedForRedraw || super.needsDisplay }
        set {
            _markedForRedraw = newValue
            super.needsDisplay = newValue
        }
    }

    // MARK: - Setup

    private func observeManager() {
        cancellables.removeAll()
        manager?.regionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.needsDisplay = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Drawing

    override var isFlipped: Bool { return false }

    override func draw(_ dirtyRect: NSRect) {
        _markedForRedraw = false
        // Clear to transparent
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard let regions = manager?.regions else { return }

        NSColor.black.setFill()
        for region in regions where region.isActive {
            region.relativeRect.fill()
        }
    }

    /// Trigger a redraw on the main thread (called by WindowTracker).
    func scheduleRedraw() {
        DispatchQueue.main.async { [weak self] in
            self?.needsDisplay = true
        }
    }
}
