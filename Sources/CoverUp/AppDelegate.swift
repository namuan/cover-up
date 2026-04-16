import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindow: OverlayWindow?
    private var maskRegionManager: MaskRegionManager?
    private var windowTracker: WindowTracker?
    private var statusMenuController: StatusMenuController?
    private var onboardingWindowController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("applicationDidFinishLaunching — activation policy: \(NSApp.activationPolicy().rawValue)")
        logInfo("allGranted=\(PermissionManager.allGranted), screenRecording=\(PermissionManager.Permission.screenRecording.isGranted)")

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
        logInfo("startCoreComponents — creating MaskRegionManager, OverlayWindow, WindowTracker, StatusMenuController")

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

        let statusCtrl = StatusMenuController(
            manager: manager,
            overlayWindow: window
        )
        statusMenuController = statusCtrl
        logInfo("StatusMenuController created — status item installed")

        logInfo("startCoreComponents complete")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo("applicationWillTerminate")
    }
}
