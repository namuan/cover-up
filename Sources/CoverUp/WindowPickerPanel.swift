import AppKit
import CoreGraphics
import Foundation

/// A floating HUD panel that lists open window titles so the user can attach a region to one.
/// After the user picks or dismisses, `onSelect` is called: `nil` = keep static, non-nil = window title to track.
final class WindowPickerPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate {

    struct WindowSelection {
        let title: String
        let cgBounds: CGRect
    }

    var onSelect: ((WindowSelection?) -> Void)?

    private var panel: NSPanel?
    private weak var tableView: NSTableView?
    private var windowSelections: [WindowSelection] = []
    private var displayTitles: [String] = []

    // MARK: - Show / Dismiss

    func show(near screenRect: CGRect) {
        let (selections, displays) = fetchWindowTitles()
        windowSelections = selections
        displayTitles = displays

        let panelWidth: CGFloat = 380
        let panelHeight: CGFloat = 290

        let screen = NSScreen.screens.first { $0.frame.intersects(screenRect) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let sf = screen.visibleFrame
        let panelRect = NSRect(
            x: sf.midX - panelWidth / 2,
            y: sf.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        let p = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        p.title = "Track a Window?"
        p.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false

        buildContent(in: p)
        panel = p
        p.makeKeyAndOrderFront(nil)
        logInfo("WindowPickerPanel shown — \(windowSelections.count) windows available")
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Content

    private func buildContent(in panel: NSPanel) {
        guard let contentView = panel.contentView else { return }

        let label = NSTextField(wrappingLabelWithString: "Pick a window to track, or keep the region static.")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let table = NSTableView()
        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.allowsEmptySelection = true
        table.rowHeight = 22
        let col = NSTableColumn(identifier: .init("title"))
        table.addTableColumn(col)
        scrollView.documentView = table
        tableView = table

        let keepButton = NSButton(title: "Keep Static", target: self, action: #selector(keepStatic))
        keepButton.keyEquivalent = "\u{1b}"
        keepButton.translatesAutoresizingMaskIntoConstraints = false

        let trackButton = NSButton(title: "Track Window", target: self, action: #selector(trackSelected))
        trackButton.keyEquivalent = "\r"
        trackButton.bezelStyle = .rounded
        trackButton.translatesAutoresizingMaskIntoConstraints = false

        [label, scrollView, keepButton, trackButton].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: keepButton.topAnchor, constant: -12),

            keepButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            keepButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            trackButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            trackButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Actions

    @objc private func keepStatic() {
        logInfo("WindowPickerPanel — user chose keep static")
        dismiss()
        onSelect?(nil)
    }

    @objc private func trackSelected() {
        let row = tableView?.selectedRow ?? -1
        let selection = (row >= 0 && row < windowSelections.count) ? windowSelections[row] : nil
        logInfo("WindowPickerPanel — user chose title=\(selection?.title ?? "nil")")
        dismiss()
        onSelect?(selection)
    }

    // MARK: - Window list

    private func fetchWindowTitles() -> (selections: [WindowSelection], displays: [String]) {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return ([], [])
        }
        let appBundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "CoverUp"
        var seen = Set<String>()
        var selections: [WindowSelection] = []
        var displays: [String] = []
        for info in list {
            guard
                let windowName = info[kCGWindowName as String] as? String,
                !windowName.isEmpty,
                let ownerName = info[kCGWindowOwnerName as String] as? String,
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                ownerName != appBundleName
            else { continue }
            guard seen.insert(windowName).inserted else { continue }
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            selections.append(WindowSelection(title: windowName, cgBounds: bounds))
            displays.append("\(ownerName)  —  \(windowName)")
        }
        return (selections, displays)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { displayTitles.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: displayTitles[row])
        cell.font = .systemFont(ofSize: 12)
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }
}
