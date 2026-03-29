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

        statusMenuController = StatusMenuController(
            manager: manager,
            hotkeyHandler: hotkeys,
            overlayWindow: window
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
