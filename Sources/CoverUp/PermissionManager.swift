import AppKit
import CoreGraphics

/// Checks and requests the macOS permissions required by CoverUp.
final class PermissionManager {

    enum Permission: CaseIterable {
        case screenRecording

        var title: String {
            switch self {
            case .screenRecording: return "Screen Recording"
            }
        }

        var detail: String {
            switch self {
            case .screenRecording:
                return "Required to track window positions so overlay regions stay aligned."
            }
        }

        var symbolName: String {
            switch self {
            case .screenRecording: return "rectangle.dashed.badge.record"
            }
        }

        var isGranted: Bool {
            switch self {
            case .screenRecording:
                let granted = CGPreflightScreenCaptureAccess()
                logDebug("PermissionManager.screenRecording.isGranted → \(granted)")
                return granted
            }
        }

        var settingsURL: URL {
            switch self {
            case .screenRecording:
                return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            }
        }

        /// Trigger the system prompt where available.
        func requestAccess() {
            logInfo("PermissionManager.requestAccess — \(title)")
            switch self {
            case .screenRecording:
                CGRequestScreenCaptureAccess()
            }
        }
    }

    /// `true` when every required permission has been granted.
    static var allGranted: Bool {
        let result = Permission.allCases.allSatisfy { $0.isGranted }
        logDebug("PermissionManager.allGranted → \(result)")
        return result
    }
}
