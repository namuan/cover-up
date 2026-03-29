import AppKit

/// Drives the status bar icon and the control panel window.
final class StatusMenuController: NSObject {

    // MARK: - Dependencies

    private let manager: MaskRegionManager
    private let hotkeyHandler: HotkeyHandler
    private weak var overlayWindow: OverlayWindow?

    // MARK: - UI

    private var statusItem: NSStatusItem?
    private var controlPanel: NSPanel?
    private var regionListController: RegionListController?

    // MARK: - Init

    init(manager: MaskRegionManager, hotkeyHandler: HotkeyHandler, overlayWindow: OverlayWindow?) {
        self.manager = manager
        self.hotkeyHandler = hotkeyHandler
        self.overlayWindow = overlayWindow
        super.init()
        logInfo("StatusMenuController init")
        setupStatusItem()
        setupHotkeys()
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

        let toggleItem = NSMenuItem(title: "Toggle Overlay", action: nil, keyEquivalent: "")
        toggleItem.keyEquivalentModifierMask = []
        toggleItem.isEnabled = false
        toggleItem.attributedTitle = NSAttributedString(
            string: "Toggle Overlay          ⌘⇧H",
            attributes: [.font: NSFont.menuFont(ofSize: 0)])
        menu.addItem(toggleItem)

        let addItem = NSMenuItem(title: "Add Region", action: nil, keyEquivalent: "")
        addItem.isEnabled = false
        addItem.attributedTitle = NSAttributedString(
            string: "Add Static Region     ⌘⇧A",
            attributes: [.font: NSFont.menuFont(ofSize: 0)])
        menu.addItem(addItem)

        let removeItem = NSMenuItem(title: "Remove Region", action: nil, keyEquivalent: "")
        removeItem.isEnabled = false
        removeItem.attributedTitle = NSAttributedString(
            string: "Remove Last Region  ⌘⇧D",
            attributes: [.font: NSFont.menuFont(ofSize: 0)])
        menu.addItem(removeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CoverUp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupHotkeys() {
        hotkeyHandler.delegate = self
        hotkeyHandler.startMonitoring()
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
}

// MARK: - HotkeyHandlerDelegate

extension StatusMenuController: HotkeyHandlerDelegate {
    func toggleOverlayVisibility() {
        guard let window = overlayWindow else {
            logWarning("StatusMenuController toggleOverlayVisibility — overlayWindow is nil")
            return
        }
        logInfo("StatusMenuController toggleOverlayVisibility — currently isVisible=\(window.isVisible)")
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func addStaticRegion() {
        guard let screen = NSScreen.main else { return }
        let cx = screen.frame.midX - 100
        let cy = screen.frame.midY - 50
        let region = MaskRegion(
            relativeRect: CGRect(x: cx, y: cy, width: 200, height: 100)
        )
        manager.addRegion(region)
    }

    func removeLastRegion() {
        guard let last = manager.regions.last else { return }
        manager.removeRegion(id: last.id)
    }
}
