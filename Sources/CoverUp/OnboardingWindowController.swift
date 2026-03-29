import AppKit

/// Manages the onboarding window. Call `showIfNeeded()` at launch.
final class OnboardingWindowController: NSWindowController {

    convenience init() {
        logInfo("OnboardingWindowController init")
        let vc = OnboardingViewController()

        let window = NSWindow(contentViewController: vc)
        window.title = "CoverUp — Permissions"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)
        logInfo("OnboardingWindowController window created — frame: \(window.frame)")
    }

    /// Shows the onboarding window if any permission is missing.
    ///
    /// Temporarily promotes the app to `.regular` activation policy so the
    /// window receives focus even though `LSUIElement = YES` normally keeps
    /// the app as an `.accessory` (no Dock icon) process.
    ///
    /// - Returns: `true` if the window was shown (some permission is missing),
    ///            `false` if all permissions are already granted.
    @discardableResult
    func showIfNeeded() -> Bool {
        logInfo("showIfNeeded — allGranted=\(PermissionManager.allGranted)")
        logInfo("  screenRecording=\(PermissionManager.Permission.screenRecording.isGranted)")
        logInfo("  accessibility=\(PermissionManager.Permission.accessibility.isGranted)")

        guard !PermissionManager.allGranted else {
            logInfo("showIfNeeded — all permissions granted, skipping window")
            return false
        }

        logInfo("showIfNeeded — setting activationPolicy to .regular")
        NSApp.setActivationPolicy(.regular)
        logInfo("showIfNeeded — activationPolicy is now \(NSApp.activationPolicy().rawValue)")

        logInfo("showIfNeeded — calling NSApp.activate")
        NSApp.activate(ignoringOtherApps: true)

        logInfo("showIfNeeded — calling makeKeyAndOrderFront + orderFrontRegardless")
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        logInfo("showIfNeeded — window.isVisible=\(window?.isVisible ?? false), window.isKeyWindow=\(window?.isKeyWindow ?? false)")
        return true
    }

    /// Call after onboarding completes to remove the Dock icon and return
    /// to headless menu-bar-only mode.
    func restoreAccessoryPolicy() {
        logInfo("restoreAccessoryPolicy — switching back to .accessory")
        NSApp.setActivationPolicy(.accessory)
    }
}
