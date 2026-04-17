import Foundation
import Combine

/// Single source of truth for all mask regions.
/// Observers receive updates via the `regionsPublisher`.
final class MaskRegionManager {

    // MARK: - Published state

    private let regionsSubject = CurrentValueSubject<[MaskRegion], Never>([])

    /// Subscribe here to be notified whenever the region list changes.
    var regionsPublisher: AnyPublisher<[MaskRegion], Never> {
        regionsSubject.eraseToAnyPublisher()
    }

    /// Current snapshot of all regions.
    var regions: [MaskRegion] { regionsSubject.value }

    // MARK: - Default style (persisted)

    private static let defaultStyleKey = "coverup.defaultStyle"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var defaultStyle: CoverStyle {
        get {
            guard let raw = userDefaults.string(forKey: Self.defaultStyleKey),
                  let style = CoverStyle(rawValue: raw) else { return .blackBox }
            return style
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Self.defaultStyleKey)
        }
    }

    // MARK: - Mutations

    /// Append a new region. No-op if a region with the same `id` already exists.
    func addRegion(_ region: MaskRegion) {
        guard !regionsSubject.value.contains(where: { $0.id == region.id }) else {
            logInfo("MaskRegionManager addRegion no-op — id \(region.id) already exists")
            return
        }
        logInfo("MaskRegionManager addRegion id=\(region.id) total=\(regionsSubject.value.count + 1)")
        regionsSubject.value.append(region)
    }

    /// Remove the region with the given id. No-op if not found.
    func removeRegion(id: String) {
        logInfo("MaskRegionManager removeRegion id=\(id)")
        regionsSubject.value.removeAll { $0.id == id }
    }

    /// Flip `isActive` for the region with the given id. No-op if not found.
    func toggleRegion(id: String) {
        guard let index = regionsSubject.value.firstIndex(where: { $0.id == id }) else { return }
        let newValue = !regionsSubject.value[index].isActive
        logInfo("MaskRegionManager toggleRegion id=\(id) isActive→\(newValue)")
        regionsSubject.value[index].isActive.toggle()
    }

    /// Update `relativeRect` for the given id (used by WindowTracker).
    func updateRect(id: String, rect: CGRect) {
        guard let index = regionsSubject.value.firstIndex(where: { $0.id == id }) else { return }
        regionsSubject.value[index].relativeRect = rect
    }

    /// Update the cover style for the given id.
    func setStyle(id: String, style: CoverStyle) {
        guard let index = regionsSubject.value.firstIndex(where: { $0.id == id }) else { return }
        logInfo("MaskRegionManager setStyle id=\(id) style=\(style.rawValue)")
        regionsSubject.value[index].style = style
    }

    /// Attach an existing screen-space region to a tracked window while preserving its
    /// current size and offset inside that window.
    func attachRegionToWindow(id: String, title: String, windowRect: CGRect) {
        guard let index = regionsSubject.value.firstIndex(where: { $0.id == id }) else { return }
        let regionRect = regionsSubject.value[index].relativeRect
        let localRect = CGRect(
            x: regionRect.origin.x - windowRect.origin.x,
            y: regionRect.origin.y - windowRect.origin.y,
            width: regionRect.width,
            height: regionRect.height
        )
        logInfo("MaskRegionManager attachRegionToWindow id=\(id) title=\(title)")
        regionsSubject.value[index].targetWindowTitle = title
        regionsSubject.value[index].trackedWindowLocalRect = localRect
    }

    /// Update `targetWindowTitle` for the given id.
    func updateTargetWindowTitle(id: String, title: String?) {
        guard let index = regionsSubject.value.firstIndex(where: { $0.id == id }) else { return }
        logInfo("MaskRegionManager updateTargetWindowTitle id=\(id) title=\(title ?? "nil")")
        regionsSubject.value[index].targetWindowTitle = title
        if title == nil {
            regionsSubject.value[index].trackedWindowLocalRect = nil
        }
    }
}
