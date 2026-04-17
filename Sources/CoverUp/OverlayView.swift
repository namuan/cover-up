import AppKit
import Combine

/// Renders all active MaskRegion rectangles as black boxes or blur overlays.
class OverlayView: NSView {

    // MARK: - Dependencies

    /// Injected by OverlayWindow after construction.
    var manager: MaskRegionManager? {
        didSet { observeManager() }
    }

    private var cancellables = Set<AnyCancellable>()
    private var _markedForRedraw = false
    private var blurViews: [String: NSVisualEffectView] = [:]
    private var cachedBlurIDs: Set<String> = []

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
            .sink { [weak self] regions in
                self?.syncBlurViews(for: regions)
                self?.needsDisplay = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Blur view management

    private func syncBlurViews(for regions: [MaskRegion]) {
        let activeBlurIDs = Set(regions.lazy.filter { $0.isActive && $0.style == .blur }.map { $0.id })

        if activeBlurIDs != cachedBlurIDs {
            cachedBlurIDs = activeBlurIDs
            for id in blurViews.keys where !activeBlurIDs.contains(id) {
                blurViews.removeValue(forKey: id)?.removeFromSuperview()
            }
            for region in regions where region.isActive && region.style == .blur && blurViews[region.id] == nil {
                let vev = NSVisualEffectView(frame: region.relativeRect)
                vev.blendingMode = .behindWindow
                vev.material = .hudWindow
                vev.state = .active
                addSubview(vev)
                blurViews[region.id] = vev
            }
        }

        // Always reposition (handles window tracking at 30 FPS)
        for region in regions where region.isActive && region.style == .blur {
            blurViews[region.id]?.frame = region.relativeRect
        }
    }

    // MARK: - Drawing

    override var isFlipped: Bool { return false }

    override func draw(_ dirtyRect: NSRect) {
        _markedForRedraw = false
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard let regions = manager?.regions else { return }

        NSColor.black.setFill()
        for region in regions where region.isActive && region.style == .blackBox {
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
