import AppKit

/// Drives the status bar icon and the control panel window.
final class StatusMenuController: NSObject {

    // MARK: - Dependencies

    private let manager: MaskRegionManager
    private weak var overlayWindow: OverlayWindow?

    // MARK: - UI

    private var statusItem: NSStatusItem?
    private var controlPanel: NSPanel?
    private var regionListController: RegionListController?
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

        let panelItem = NSMenuItem(title: "Show Control Panel", action: #selector(showControlPanel), keyEquivalent: "")
        panelItem.target = self
        menu.addItem(panelItem)

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

    // MARK: - Control Panel

    @objc func showControlPanel() {
        logInfo("StatusMenuController showControlPanel")
        if controlPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 400),
                styleMask: [.titled, .closable, .resizable, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.title = "CoverUp — Regions"
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.center()

            let listController = RegionListController(manager: manager)
            panel.contentViewController = listController
            regionListController = listController
            controlPanel = panel
        }
        controlPanel?.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
