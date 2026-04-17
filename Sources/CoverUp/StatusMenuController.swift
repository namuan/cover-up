import AppKit

/// Drives the status bar icon and the control panel window.
final class StatusMenuController: NSObject, NSMenuDelegate {

    // MARK: - Dependencies

    private let manager: MaskRegionManager
    private weak var overlayWindow: OverlayWindow?

    // MARK: - UI

    private var statusItem: NSStatusItem?
    private lazy var drawingController = RegionDrawingWindowController(manager: manager)

    private enum MenuTag {
        static let styleItem = 101
        static let regionsHeader = 102
        static let regionItem = 103
    }

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
        menu.delegate = self

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

        // Default style section
        menu.addItem(NSMenuItem.separator())

        let styleHeader = NSMenuItem(title: "Default Style for New Regions", action: nil, keyEquivalent: "")
        styleHeader.isEnabled = false
        menu.addItem(styleHeader)

        for style in CoverStyle.allCases {
            let item = NSMenuItem(title: "    \(style.rawValue)", action: #selector(menuSetDefaultStyle(_:)), keyEquivalent: "")
            item.target = self
            item.tag = MenuTag.styleItem
            item.representedObject = style
            menu.addItem(item)
        }

        // Regions section — rebuilt dynamically in menuWillOpen
        menu.addItem(NSMenuItem.separator())

        let regionsHeader = NSMenuItem(title: "Regions", action: nil, keyEquivalent: "")
        regionsHeader.isEnabled = false
        regionsHeader.tag = MenuTag.regionsHeader
        menu.addItem(regionsHeader)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CoverUp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        for item in menu.items where item.tag == MenuTag.styleItem {
            guard let style = item.representedObject as? CoverStyle else { continue }
            item.state = (style == manager.defaultStyle) ? .on : .off
        }
        rebuildRegionItems(in: menu)
    }

    private func rebuildRegionItems(in menu: NSMenu) {
        for item in menu.items.filter({ $0.tag == MenuTag.regionItem }) {
            menu.removeItem(item)
        }

        guard let headerIdx = menu.items.firstIndex(where: { $0.tag == MenuTag.regionsHeader }) else { return }

        let regions = manager.regions
        if regions.isEmpty {
            let empty = NSMenuItem(title: "    No Regions", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            empty.tag = MenuTag.regionItem
            menu.insertItem(empty, at: headerIdx + 1)
        } else {
            for (offset, region) in regions.enumerated() {
                let label = "    Region \(offset + 1)  [\(region.style.rawValue)]  →  \(region.style.toggled.rawValue)"
                let item = NSMenuItem(title: label, action: #selector(menuToggleRegionStyle(_:)), keyEquivalent: "")
                item.target = self
                item.tag = MenuTag.regionItem
                item.representedObject = region.id
                menu.insertItem(item, at: headerIdx + 1 + offset)
            }
        }
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

    @objc private func menuSetDefaultStyle(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? CoverStyle else { return }
        logInfo("StatusMenuController setDefaultStyle \(style.rawValue)")
        manager.defaultStyle = style
    }

    @objc private func menuToggleRegionStyle(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let region = manager.regions.first(where: { $0.id == id }) else { return }
        logInfo("StatusMenuController toggleRegionStyle id=\(id) → \(region.style.toggled.rawValue)")
        manager.setStyle(id: id, style: region.style.toggled)
    }
}
