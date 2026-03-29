import AppKit
import Combine

// MARK: - Window (accepts key events)

private final class RegionDrawingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Window Controller

/// Manages the full-screen drawing/selection overlay.
/// Activate to let the user drag-draw new regions or click-select existing ones to delete.
final class RegionDrawingWindowController: NSObject {

    private let manager: MaskRegionManager
    private var window: NSWindow?

    init(manager: MaskRegionManager) {
        self.manager = manager
    }

    func activate() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let allScreensFrame = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }

        let win = RegionDrawingWindow(
            contentRect: allScreensFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        // One level above the overlay window (.screenSaver)
        win.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let view = RegionDrawingView(frame: CGRect(origin: .zero, size: allScreensFrame.size))
        view.manager = manager
        view.screenOrigin = allScreensFrame.origin
        view.onDismiss = { [weak self] in self?.deactivate() }

        win.contentView = view
        win.makeFirstResponder(view)

        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logInfo("RegionDrawingWindowController activated — frame=\(allScreensFrame)")
    }

    func deactivate() {
        window?.orderOut(nil)
        window = nil
        logInfo("RegionDrawingWindowController deactivated")
    }
}

// MARK: - Drawing View

final class RegionDrawingView: NSView {

    var manager: MaskRegionManager? {
        didSet {
            cancellables.removeAll()
            manager?.regionsPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.needsDisplay = true }
                .store(in: &cancellables)
        }
    }

    /// The screen coordinate of the view's (0, 0) point (union rect origin).
    var screenOrigin: NSPoint = .zero

    var onDismiss: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var dragOrigin: NSPoint?
    private var rubberBandRect: NSRect?
    private var selectedID: String?
    private var windowPicker: WindowPickerPanel?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        if let hit = hitRegion(at: pt) {
            // Toggle selection; deselect if tapping the already-selected region
            selectedID = (selectedID == hit.id) ? nil : hit.id
            dragOrigin = nil
            rubberBandRect = nil
        } else {
            selectedID = nil
            dragOrigin = pt
            rubberBandRect = nil
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let pt = convert(event.locationInWindow, from: nil)
        rubberBandRect = NSRect(
            x: min(origin.x, pt.x),
            y: min(origin.y, pt.y),
            width: abs(pt.x - origin.x),
            height: abs(pt.y - origin.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragOrigin = nil
            rubberBandRect = nil
            needsDisplay = true
        }
        guard let rect = rubberBandRect, rect.width > 4, rect.height > 4 else { return }

        // Convert view coords → screen coords (relativeRect storage format)
        let screenRect = CGRect(
            x: rect.origin.x + screenOrigin.x,
            y: rect.origin.y + screenOrigin.y,
            width: rect.width,
            height: rect.height
        )
        let region = MaskRegion(relativeRect: screenRect)
        manager?.addRegion(region)
        logInfo("RegionDrawingView added region rect=\(screenRect)")
        showWindowPicker(for: region.id, near: screenRect)
        // Stay open so user can draw additional regions or delete existing ones
    }

    private func showWindowPicker(for regionID: String, near screenRect: CGRect) {
        let picker = WindowPickerPanel()
        windowPicker = picker
        picker.onSelect = { [weak self] title in
            guard let self else { return }
            self.windowPicker = nil
            if let title {
                self.manager?.updateTargetWindowTitle(id: regionID, title: title)
            }
            // Restore key focus to the drawing overlay
            self.window?.makeKeyAndOrderFront(nil)
            self.window?.makeFirstResponder(self)
        }
        picker.show(near: screenRect)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            onDismiss?()
        case 51, 117: // Backspace / Forward Delete
            if let id = selectedID {
                manager?.removeRegion(id: id)
                selectedID = nil
                needsDisplay = true
            }
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Coordinate helpers

    private func hitRegion(at viewPt: NSPoint) -> MaskRegion? {
        guard let regions = manager?.regions else { return nil }
        // Reverse so the most recently added region wins on overlap
        return regions.reversed().first { viewRect(for: $0).contains(viewPt) }
    }

    /// Converts a region's screen-coordinate rect to this view's coordinate space.
    private func viewRect(for region: MaskRegion) -> NSRect {
        NSRect(
            x: region.relativeRect.origin.x - screenOrigin.x,
            y: region.relativeRect.origin.y - screenOrigin.y,
            width: region.relativeRect.width,
            height: region.relativeRect.height
        )
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent dark curtain
        NSColor(white: 0, alpha: 0.4).setFill()
        bounds.fill()

        drawBanner()

        for region in manager?.regions ?? [] {
            drawRegion(region)
        }

        if let rect = rubberBandRect, rect.width > 1, rect.height > 1 {
            drawRubberBand(rect)
        }
    }

    private func drawBanner() {
        let text: String
        if selectedID != nil {
            text = "Press Delete to remove selected region  •  Esc to close"
        } else {
            text = "Drag to draw a region  •  Click a region to select  •  Delete to remove  •  Esc to close"
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let padding: CGFloat = 10
        let bannerRect = NSRect(
            x: (bounds.width - textSize.width) / 2 - padding,
            y: bounds.height - textSize.height - 20 - padding * 2,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        NSColor(white: 0, alpha: 0.75).setFill()
        NSBezierPath(roundedRect: bannerRect, xRadius: 8, yRadius: 8).fill()
        str.draw(at: NSPoint(x: bannerRect.minX + padding, y: bannerRect.minY + padding))
    }

    private func drawRegion(_ region: MaskRegion) {
        let rect = viewRect(for: region)
        let isSelected = region.id == selectedID

        NSColor.black.setFill()
        rect.fill()

        let borderColor: NSColor = isSelected ? .systemRed : NSColor(white: 1, alpha: 0.5)
        borderColor.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = isSelected ? 2 : 1
        border.stroke()

        if isSelected {
            let hint = "Delete to remove"
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 11)
            ]
            let hintStr = NSAttributedString(string: hint, attributes: hintAttrs)
            let hintSize = hintStr.size()
            let hintOrigin = NSPoint(
                x: rect.midX - hintSize.width / 2,
                y: rect.midY - hintSize.height / 2
            )
            let bgRect = NSRect(
                x: hintOrigin.x - 4, y: hintOrigin.y - 2,
                width: hintSize.width + 8, height: hintSize.height + 4
            )
            NSColor(white: 0, alpha: 0.75).setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
            hintStr.draw(at: hintOrigin)
        }

        // Show tracking badge when a window title is assigned
        if let title = region.targetWindowTitle, !title.isEmpty {
            let badge = "⇄ \(title)"
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 10)
            ]
            let badgeStr = NSAttributedString(string: badge, attributes: badgeAttrs)
            let badgeSize = badgeStr.size()
            let maxWidth = rect.width - 8
            let clampedWidth = min(badgeSize.width, maxWidth)
            let badgeOrigin = NSPoint(x: rect.minX + 4, y: rect.minY + 4)
            let bgRect = NSRect(
                x: badgeOrigin.x - 2, y: badgeOrigin.y - 2,
                width: clampedWidth + 8, height: badgeSize.height + 4
            )
            NSColor(calibratedRed: 0.2, green: 0.5, blue: 1.0, alpha: 0.85).setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3).fill()

            let clipPath = NSBezierPath(rect: NSRect(
                x: badgeOrigin.x, y: badgeOrigin.y,
                width: clampedWidth, height: badgeSize.height
            ))
            NSGraphicsContext.saveGraphicsState()
            clipPath.setClip()
            badgeStr.draw(at: badgeOrigin)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawRubberBand(_ rect: NSRect) {
        NSColor(white: 1, alpha: 0.12).setFill()
        rect.fill()
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1.5
        path.setLineDash([6, 3], count: 2, phase: 0)
        path.stroke()
    }
}
