import AppKit

/// Defines the actions hotkeyHandler can trigger.
protocol HotkeyHandlerDelegate: AnyObject {
    func toggleOverlayVisibility()
    func addStaticRegion()
    func removeLastRegion()
}

/// Translates keyboard events into app actions.
/// The global NSEvent monitor calls `handleKeyEvent(flags:keyCode:)`.
final class HotkeyHandler {

    weak var delegate: HotkeyHandlerDelegate?

    private var monitor: Any?

    // Key codes
    static let keyH: UInt16 = 4   // H
    static let keyA: UInt16 = 0   // A
    static let keyD: UInt16 = 2   // D

    // MARK: - Lifecycle

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(flags: event.modifierFlags, keyCode: event.keyCode)
        }
    }

    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    // MARK: - Action dispatch (public for testing)

    /// Process a key event. Fired by the global monitor or directly in tests.
    func handleKeyEvent(flags: NSEvent.ModifierFlags, keyCode: UInt16) {
        let required: NSEvent.ModifierFlags = [.command, .shift]
        guard flags.intersection(.deviceIndependentFlagsMask).contains(required) else { return }

        switch keyCode {
        case HotkeyHandler.keyH:
            delegate?.toggleOverlayVisibility()
        case HotkeyHandler.keyA:
            delegate?.addStaticRegion()
        case HotkeyHandler.keyD:
            delegate?.removeLastRegion()
        default:
            break
        }
    }
}
