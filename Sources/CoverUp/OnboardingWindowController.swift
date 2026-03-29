import AppKit

/// Manages the onboarding window. Call `showIfNeeded()` at launch.
final class OnboardingWindowController: NSWindowController {

    convenience init() {
        let vc = OnboardingViewController()

        let window = NSWindow(contentViewController: vc)
        window.title = "CoverUp — Permissions"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)
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
        guard !PermissionManager.allGranted else { return false }
        // Switch to .regular so the window appears and receives keyboard focus.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        return true
    }

    /// Call after onboarding completes to remove the Dock icon and return
    /// to headless menu-bar-only mode.
    func restoreAccessoryPolicy() {
        NSApp.setActivationPolicy(.accessory)
    }
}
