import Foundation
import CoreGraphics

/// A single screen region to be masked (blacked out or blurred in a future phase).
struct MaskRegion: Equatable, Identifiable {
    /// Unique identifier (UUID string).
    var id: String
    /// Optional window title to track. `nil` = static position.
    var targetWindowTitle: String?
    /// Optional region rect in the tracked window's local coordinates.
    /// When present, only this sub-rectangle is moved with the window.
    var trackedWindowLocalRect: CGRect?
    /// Position and size in screen coordinates (AppKit bottom-left origin).
    var relativeRect: CGRect
    /// `false` = solid black box (Phase 1). `true` = blur (future).
    var useBlur: Bool
    /// When `false`, region is not rendered.
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        targetWindowTitle: String? = nil,
        trackedWindowLocalRect: CGRect? = nil,
        relativeRect: CGRect = .zero,
        useBlur: Bool = false,
        isActive: Bool = true
    ) {
        self.id = id
        self.targetWindowTitle = targetWindowTitle
        self.trackedWindowLocalRect = trackedWindowLocalRect
        self.relativeRect = relativeRect
        self.useBlur = useBlur
        self.isActive = isActive
    }
}
