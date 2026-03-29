import CoreGraphics
import Foundation

/// Abstraction over CGWindowListCopyWindowInfo to allow injection in tests.
protocol CGWindowListProvider {
    /// Returns an array of window info dictionaries (same shape as CGWindowListCopyWindowInfo output).
    func windowList() -> [[String: Any]]
}

/// Production implementation that calls the real CGWindow API.
final class SystemCGWindowListProvider: CGWindowListProvider {
    func windowList() -> [[String: Any]] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list
    }
}
