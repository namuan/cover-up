import AppKit

/// Drives the status bar icon and the control panel window.
final class StatusMenuController: NSObject {

    // MARK: - Dependencies

    private let manager: MaskRegionManager
    private weak var overlayWindow: OverlayWindow?

    // MARK: - UI

    private var statusItem: NSStatusItem?
    private lazy var drawingController = RegionDrawingWindowController(manager: manager)

    // MARK: - Init

    init(manager: MaskRegionManager, overlayWindow: OverlayWindow?) {
        self.manager = manager
        self.overlayWindow = overlayWindow
        super.init()
        logInfo("StatusMenuController init")
        setupStatusItem()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.title = "◼"
        statusItem?.button?.toolTip = "CoverUp"

        let menu = NSMenu()

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Overlay", action: #selector(menuToggleOverlay), keyEquivalent: "h")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        let addItem = NSMenuItem(title: "Add Static Region", action: #selector(menuAddRegion), keyEquivalent: "a")
        addItem.keyEquivalentModifierMask = [.command, .shift]
        addItem.target = self
        menu.addItem(addItem)

        let removeItem = NSMenuItem(title: "Remove Last Region", action: #selector(menuRemoveLastRegion), keyEquivalent: "d")
        removeItem.keyEquivalentModifierMask = [.command, .shift]
        removeItem.target = self
        menu.addItem(removeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CoverUp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func menuToggleOverlay() {
        guard let window = overlayWindow else { return }
        logInfo("StatusMenuController toggleOverlay — currently isVisible=\(window.isVisible)")
        if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
    }

    @objc private func menuAddRegion() {
        drawingController.activate()
    }

    @objc private func menuRemoveLastRegion() {
        guard let last = manager.regions.last else { return }
        manager.removeRegion(id: last.id)
    }
}
