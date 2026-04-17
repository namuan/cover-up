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
        let region = MaskRegion(relativeRect: screenRect, style: manager?.defaultStyle ?? .blackBox)
        manager?.addRegion(region)
        logInfo("RegionDrawingView added region rect=\(screenRect)")
        showWindowPicker(for: region.id, near: screenRect)
        // Stay open so user can draw additional regions or delete existing ones
    }

    private func showWindowPicker(for regionID: String, near screenRect: CGRect) {
        let picker = WindowPickerPanel()
        windowPicker = picker
        picker.onSelect = { [weak self] selection in
            guard let self else { return }
            self.windowPicker = nil
            if let selection {
                let windowRect = WindowTracker.convertToAppKit(cgWindowBounds: selection.cgBounds)
                self.manager?.attachRegionToWindow(id: regionID, title: selection.title, windowRect: windowRect)
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

        switch region.style {
        case .blackBox:
            NSColor.black.setFill()
        case .blur:
            NSColor(white: 0.5, alpha: 0.55).setFill()
        }
        rect.fill()

        let borderColor: NSColor = isSelected ? .systemRed : NSColor(white: 1, alpha: 0.5)
        borderColor.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = isSelected ? 2 : 1
        border.stroke()

        if isSelected {
            let hintText = "Delete to remove"
            let hintSize = NSAttributedString(string: hintText, attributes: [
                .font: NSFont.systemFont(ofSize: 11)
            ]).size()
            let hintOrigin = NSPoint(x: rect.midX - hintSize.width / 2, y: rect.midY - hintSize.height / 2)
            drawBadge(hintText, at: hintOrigin, backgroundColor: NSColor(white: 0, alpha: 0.75),
                      fontSize: 11, hPad: 4, cornerRadius: 4)
        }

        // Style badge (bottom-right corner)
        let styleText = region.style == .blur ? "◌ Blur" : "■ Black Box"
        let styleTextWidth = NSAttributedString(string: styleText, attributes: [.font: NSFont.systemFont(ofSize: 10)]).size().width
        let styleBadgeOrigin = NSPoint(x: rect.maxX - styleTextWidth - 6, y: rect.minY + 4)
        drawBadge(styleText, at: styleBadgeOrigin, backgroundColor: NSColor(white: 0, alpha: 0.6))

        // Show tracking badge when a window title is assigned
        if let title = region.targetWindowTitle, !title.isEmpty {
            let trackOrigin = NSPoint(x: rect.minX + 4, y: rect.minY + 4)
            drawBadge("⇄ \(title)", at: trackOrigin,
                      backgroundColor: NSColor(calibratedRed: 0.2, green: 0.5, blue: 1.0, alpha: 0.85),
                      maxWidth: rect.width - 8)
        }
    }

    private func drawBadge(
        _ text: String,
        at origin: NSPoint,
        backgroundColor: NSColor,
        fontSize: CGFloat = 10,
        hPad: CGFloat = 2,
        cornerRadius: CGFloat = 3,
        maxWidth: CGFloat? = nil
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: fontSize)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let drawWidth = maxWidth.map { min(textSize.width, $0) } ?? textSize.width
        let bgRect = NSRect(x: origin.x - hPad, y: origin.y - 2,
                            width: drawWidth + hPad * 2 + 4, height: textSize.height + 4)
        backgroundColor.setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        if let maxWidth, drawWidth < textSize.width {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: origin.x, y: origin.y, width: drawWidth, height: textSize.height)).setClip()
            str.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            str.draw(at: origin)
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
