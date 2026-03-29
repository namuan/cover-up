import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var maskRegionManager: MaskRegionManager?
    private var windowTracker: WindowTracker?
    private var statusMenuController: StatusMenuController?
    private var hotkeyHandler: HotkeyHandler?
    private var onboardingWindowController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("applicationDidFinishLaunching — activation policy: \(NSApp.activationPolicy().rawValue)")
        logInfo("allGranted=\(PermissionManager.allGranted), screenRecording=\(PermissionManager.Permission.screenRecording.isGranted), accessibility=\(PermissionManager.Permission.accessibility.isGranted)")

        let onboarding = OnboardingWindowController()
        onboardingWindowController = onboarding

        if onboarding.showIfNeeded() {
            logInfo("Permissions missing — presenting onboarding window")
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onboardingDidComplete),
                name: .onboardingDidComplete,
                object: nil
            )
        } else {
            logInfo("All permissions already granted — skipping onboarding")
            startCoreComponents()
        }
    }

    @objc private func onboardingDidComplete() {
        logInfo("onboardingDidComplete — restoring accessory policy and starting core components")
        NotificationCenter.default.removeObserver(self, name: .onboardingDidComplete, object: nil)
        onboardingWindowController?.restoreAccessoryPolicy()
        startCoreComponents()
    }

    private func startCoreComponents() {
        logInfo("startCoreComponents — creating MaskRegionManager, OverlayWindow, WindowTracker, HotkeyHandler, StatusMenuController")

        let manager = MaskRegionManager()
        maskRegionManager = manager

        let window = OverlayWindow(manager: manager)
        overlayWindow = window
        logInfo("OverlayWindow created — frame: \(window.frame), level: \(window.level.rawValue), isVisible: \(window.isVisible)")

        let tracker = WindowTracker(manager: manager)
        tracker.onUpdate = { [weak window] in
            window?.overlayView?.scheduleRedraw()
        }
        windowTracker = tracker
        tracker.start()
        logInfo("WindowTracker started")

        let hotkeys = HotkeyHandler()
        hotkeyHandler = hotkeys

        let statusCtrl = StatusMenuController(
            manager: manager,
            hotkeyHandler: hotkeys,
            overlayWindow: window
        )
        statusMenuController = statusCtrl
        logInfo("StatusMenuController created — status item installed")

        let args = ProcessInfo.processInfo.arguments
        if args.contains("--add-test-region") {
            logInfo("--add-test-region arg detected — adding uitest-region-1")
            let region = MaskRegion(
                id: "uitest-region-1",
                relativeRect: CGRect(x: 100, y: 100, width: 200, height: 100)
            )
            manager.addRegion(region)
        }
        if args.contains("--open-control-panel") {
            logInfo("--open-control-panel arg detected — will open panel in 0.5s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                statusCtrl.showControlPanel()
            }
        }

        logInfo("startCoreComponents complete")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("applicationWillTerminate")
    }
}
