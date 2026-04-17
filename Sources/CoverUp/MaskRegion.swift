import Foundation
import CoreGraphics

enum CoverStyle: String, Codable, CaseIterable {
    case blackBox = "Black Box"
    case blur = "Blur"

    var toggled: CoverStyle { self == .blackBox ? .blur : .blackBox }
}

/// A single screen region to be masked.
struct MaskRegion: Equatable, Identifiable {
    /// Unique identifier (UUID string).
    var id: String
    /// Optional window title to track. `nil` = static position.
    var targetWindowTitle: String?
    /// Optional region rect in the tracked window's local coordinates.
    var trackedWindowLocalRect: CGRect?
    /// Position and size in screen coordinates (AppKit bottom-left origin).
    var relativeRect: CGRect
    /// How the region is rendered.
    var style: CoverStyle
    /// When `false`, region is not rendered.
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        targetWindowTitle: String? = nil,
        trackedWindowLocalRect: CGRect? = nil,
        relativeRect: CGRect = .zero,
        style: CoverStyle = .blackBox,
        isActive: Bool = true
    ) {
        self.id = id
        self.targetWindowTitle = targetWindowTitle
        self.trackedWindowLocalRect = trackedWindowLocalRect
        self.relativeRect = relativeRect
        self.style = style
        self.isActive = isActive
    }
}
