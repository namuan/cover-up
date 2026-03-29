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
    /// - Returns: `true` if the window was shown (some permission is missing),
    ///            `false` if all permissions are already granted.
    @discardableResult
    func showIfNeeded() -> Bool {
        guard !PermissionManager.allGranted else { return false }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
