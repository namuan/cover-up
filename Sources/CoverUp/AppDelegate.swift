import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var maskRegionManager: MaskRegionManager?
    private var windowTracker: WindowTracker?
    private var statusMenuController: StatusMenuController?
    private var hotkeyHandler: HotkeyHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = MaskRegionManager()
        maskRegionManager = manager

        let window = OverlayWindow(manager: manager)
        overlayWindow = window

        let tracker = WindowTracker(manager: manager)
        tracker.onUpdate = { [weak window] in
            window?.overlayView?.scheduleRedraw()
        }
        windowTracker = tracker
        tracker.start()

        let hotkeys = HotkeyHandler()
        hotkeyHandler = hotkeys

        let statusCtrl = StatusMenuController(
            manager: manager,
            hotkeyHandler: hotkeys,
            overlayWindow: window
        )
        statusMenuController = statusCtrl

        // Test support: launch arguments for XCUITest
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--add-test-region") {
            let region = MaskRegion(
                id: "uitest-region-1",
                relativeRect: CGRect(x: 100, y: 100, width: 200, height: 100)
            )
            manager.addRegion(region)
        }
        if args.contains("--open-control-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                statusCtrl.showControlPanel()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
