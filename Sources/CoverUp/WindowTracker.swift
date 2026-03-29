import AppKit
import Foundation

/// Polls window positions at ~30 FPS and updates MaskRegion positions in MaskRegionManager.
final class WindowTracker {

    // MARK: - Dependencies

    private let manager: MaskRegionManager
    private let provider: CGWindowListProvider

    // MARK: - State

    private var timer: Timer?
    private(set) var isRunning: Bool = false

    // MARK: - Callback

    /// Called on the main queue after each update cycle — use to trigger overlay redraw.
    var onUpdate: (() -> Void)?

    // MARK: - Init

    init(manager: MaskRegionManager, provider: CGWindowListProvider = SystemCGWindowListProvider()) {
        self.manager = manager
        self.provider = provider
    }

    // MARK: - Lifecycle

    /// Start polling at 30 FPS (~33 ms interval).
    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// Stop polling.
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // MARK: - Core loop

    private func tick() {
        let windowInfoList = provider.windowList()

        for region in manager.regions {
            guard let title = region.targetWindowTitle, !title.isEmpty else {
                continue // static region — leave rect unchanged
            }

            if let windowBounds = findWindowBounds(title: title, in: windowInfoList) {
                let converted = convertToAppKit(cgWindowBounds: windowBounds)
                manager.updateRect(id: region.id, rect: converted)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?()
        }
    }

    // MARK: - Helpers

    /// Find the bounds of the first visible window whose name contains `title` (case-insensitive).
    private func findWindowBounds(title: String, in list: [[String: Any]]) -> CGRect? {
        for info in list {
            guard
                let name = info[kCGWindowName as String] as? String,
                name.localizedCaseInsensitiveContains(title),
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            let x = boundsDict["X"] ?? 0
            let y = boundsDict["Y"] ?? 0
            let w = boundsDict["Width"] ?? 0
            let h = boundsDict["Height"] ?? 0
            return CGRect(x: x, y: y, width: w, height: h)
        }
        return nil
    }

    /// Convert a CGWindow rect (top-left origin, points on main screen) to
    /// AppKit coordinates (bottom-left origin on the same screen).
    ///
    /// CGWindowListCopyWindowInfo already returns logical points (not pixels),
    /// so no backing-scale-factor division is needed here.
    func convertToAppKit(cgWindowBounds rect: CGRect) -> CGRect {
        // CGWindow y=0 is at the TOP of the primary screen.
        // AppKit y=0 is at the BOTTOM of the primary screen.
        guard let primaryScreen = NSScreen.screens.first else { return rect }
        let screenHeight = primaryScreen.frame.height
        let appKitY = screenHeight - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: appKitY, width: rect.width, height: rect.height)
    }
}
