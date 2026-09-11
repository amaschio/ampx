import CoreGraphics
import Foundation

/// Persists each panel's position as an **offset from the main window's origin**, so the docked
/// arrangement survives relaunch regardless of where the main window ends up. Geometry is the source
/// of truth in the docking model, so this is the thing worth saving (there is no semantic order).
@MainActor
final class AmpXPanelPositionStore {
    private static let key = "winampPanelOffsets"

    private var offsets: [AmpXPanelID: CGSize]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.offsets = Self.load(from: defaults)
    }

    func offset(for id: AmpXPanelID) -> CGSize? {
        self.offsets[id]
    }

    /// Record `panelOrigin` relative to `mainOrigin` and persist.
    func store(_ id: AmpXPanelID, panelOrigin: CGPoint, mainOrigin: CGPoint) {
        self.offsets[id] = CGSize(
            width: panelOrigin.x - mainOrigin.x,
            height: panelOrigin.y - mainOrigin.y
        )
        self.persist()
    }

    /// The absolute origin for `id` given the current main-window origin, or `nil` if unsaved.
    func origin(for id: AmpXPanelID, mainOrigin: CGPoint) -> CGPoint? {
        guard let offset = self.offsets[id] else { return nil }
        return CGPoint(x: mainOrigin.x + offset.width, y: mainOrigin.y + offset.height)
    }

    private func persist() {
        var encoded: [String: [CGFloat]] = [:]
        for (id, offset) in self.offsets {
            encoded[id.rawValue] = [offset.width, offset.height]
        }
        self.defaults.set(encoded, forKey: Self.key)
    }

    private static func load(from defaults: UserDefaults) -> [AmpXPanelID: CGSize] {
        guard let encoded = defaults.dictionary(forKey: key) as? [String: [CGFloat]] else {
            return [:]
        }
        var result: [AmpXPanelID: CGSize] = [:]
        for (raw, pair) in encoded where pair.count == 2 {
            result[AmpXPanelID(raw)] = CGSize(width: pair[0], height: pair[1])
        }
        return result
    }
}
