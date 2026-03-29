import AppKit

/// A transparent, always-on-top, click-through window that spans all screens.
class OverlayWindow: NSWindow {

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        // Compute union frame of all screens
        let frame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        configure()
    }

    private func configure() {
        // Transparent background
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // Always on top — above screen savers too
        level = .screenSaver
        // Click-through
        ignoresMouseEvents = true
        // Keep on top even when app is inactive
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // Content view
        let overlayView = OverlayView(frame: self.frame)
        contentView = overlayView
        // Show immediately
        orderFrontRegardless()
    }

    /// Convenience: the typed content view.
    var overlayView: OverlayView? {
        return contentView as? OverlayView
    }
}
