import AppKit

/// A transparent, always-on-top, click-through window that spans all screens.
class OverlayWindow: NSWindow {

    private(set) var overlayViewInstance: OverlayView?

    convenience init(manager: MaskRegionManager? = nil) {
        let frame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        self.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        overlayView?.manager = manager
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        let frame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let frame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        let view = OverlayView(frame: frame)
        contentView = view
        overlayViewInstance = view

        orderFrontRegardless()
    }

    /// Convenience typed accessor.
    var overlayView: OverlayView? {
        return contentView as? OverlayView
    }
}
