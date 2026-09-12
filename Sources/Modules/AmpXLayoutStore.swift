import AppKit
import CoreGraphics
import Foundation

struct AmpXSavedLayout: Equatable {
    var state: AmpXModuleOrder
    var stackFrame: CGRect
    var detachedFrames: [AmpXModuleID: CGRect]
    var playlistViewportHeight: CGFloat
}

@MainActor
final class AmpXLayoutStore {
    static let storageKey = "AmpXModuleLayoutV1"

    private let defaults: UserDefaults
    private let screen: NSScreen

    init(defaults: UserDefaults, screen: NSScreen? = nil) {
        self.defaults = defaults
        self.screen = screen ?? NSScreen.main ?? NSScreen.screens.first!
    }

    func load() -> AmpXSavedLayout {
        load(screen: screen)
    }

    func load(screen: NSScreen) -> AmpXSavedLayout {
        guard let data = defaults.data(forKey: Self.storageKey),
              let dto = try? JSONDecoder().decode(AmpXLayoutV1DTO.self, from: data)
        else {
            return Self.defaultLayout(for: screen)
        }

        guard dto.version == 1 else {
            return Self.defaultLayout(for: screen)
        }

        return Self.normalizedLayout(from: dto, screen: screen)
    }

    func save(_ layout: AmpXSavedLayout) {
        let dto = AmpXLayoutV1DTO(layout: layout)
        guard let data = try? JSONEncoder().encode(dto) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    static func defaultLayout(for screen: NSScreen) -> AmpXSavedLayout {
        AmpXSavedLayout(
            state: AmpXModuleOrder(),
            stackFrame: defaultStackFrame(for: screen),
            detachedFrames: [:],
            playlistViewportHeight: AmpXMetrics.defaultPlaylistViewportHeight
        )
    }

    static func defaultStackFrame(for screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let width = AmpXMetrics.compositionWidth
        let height: CGFloat = 600
        return CGRect(
            x: visible.midX - width / 2,
            y: visible.maxY - height - 20,
            width: width,
            height: height
        )
    }

    fileprivate static func normalizedLayout(from dto: AmpXLayoutV1DTO, screen: NSScreen) -> AmpXSavedLayout {
        var state = AmpXModuleOrder()
        state.order = normalizedOrder(dto.order)
        state.collapsed = normalizedIDSet(dto.collapsed)
        state.detached = normalizedIDSet(dto.detached)
        state.closed = normalizedIDSet(dto.closed)

        enforcePlayerRules(on: &state)

        let stackFrame = validatedFrame(dto.stackFrame?.cgRect, fallback: defaultStackFrame(for: screen), screen: screen)
        let detachedFrames = normalizedDetachedFrames(dto.detachedFrames, screen: screen)
        let playlistViewportHeight = validatedPlaylistViewportHeight(dto.playlistViewportHeight)

        return AmpXSavedLayout(
            state: state,
            stackFrame: stackFrame,
            detachedFrames: detachedFrames,
            playlistViewportHeight: playlistViewportHeight
        )
    }

    private static func normalizedOrder(_ rawIDs: [String]) -> [AmpXModuleID] {
        var seen = Set<AmpXModuleID>()
        var order: [AmpXModuleID] = []

        for rawID in rawIDs {
            guard let id = AmpXModuleID(rawValue: rawID), !seen.contains(id) else { continue }
            seen.insert(id)
            order.append(id)
        }

        if !order.contains(.player) {
            order.insert(.player, at: 0)
        }

        for id in AmpXModuleID.allCases where !seen.contains(id) {
            order.append(id)
            seen.insert(id)
        }

        return order
    }

    private static func normalizedIDSet(_ rawIDs: [String]) -> Set<AmpXModuleID> {
        var result = Set<AmpXModuleID>()
        for rawID in rawIDs {
            guard let id = AmpXModuleID(rawValue: rawID) else { continue }
            result.insert(id)
        }
        return result
    }

    private static func enforcePlayerRules(on state: inout AmpXModuleOrder) {
        state.closed.remove(.player)
        state.detached.remove(.player)

        if !state.order.contains(.player) {
            state.order.insert(.player, at: 0)
        }
    }

    private static func validatedFrame(_ frame: CGRect?, fallback: CGRect, screen: NSScreen) -> CGRect {
        guard let frame, isValidFrame(frame) else { return fallback }
        return clampedToVisibleFrame(frame, screen: screen)
    }

    private static func normalizedDetachedFrames(
        _ rawFrames: [String: AmpXFrameDTO]?,
        screen: NSScreen
    ) -> [AmpXModuleID: CGRect] {
        guard let rawFrames else { return [:] }

        var frames: [AmpXModuleID: CGRect] = [:]
        for (rawID, dto) in rawFrames {
            guard let id = AmpXModuleID(rawValue: rawID),
                  let frame = dto.cgRect,
                  isValidFrame(frame)
            else { continue }
            frames[id] = clampedToVisibleFrame(frame, screen: screen)
        }
        return frames
    }

    private static func validatedPlaylistViewportHeight(_ rawValue: Double?) -> CGFloat {
        guard let rawValue, rawValue.isFinite, rawValue > 0 else {
            return AmpXMetrics.defaultPlaylistViewportHeight
        }
        return max(rawValue, AmpXMetrics.minimumPlaylistViewportHeight)
    }

    static func isValidFrame(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite
            && frame.origin.y.isFinite
            && frame.size.width.isFinite
            && frame.size.height.isFinite
            && frame.size.width > 0
            && frame.size.height > 0
    }

    static func clampedToVisibleFrame(_ frame: CGRect, screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        var clamped = frame

        if clamped.width > visible.width {
            clamped.size.width = visible.width
        }
        if clamped.height > visible.height {
            clamped.size.height = visible.height
        }

        if clamped.maxX > visible.maxX {
            clamped.origin.x = visible.maxX - clamped.width
        }
        if clamped.minX < visible.minX {
            clamped.origin.x = visible.minX
        }
        if clamped.maxY > visible.maxY {
            clamped.origin.y = visible.maxY - clamped.height
        }
        if clamped.minY < visible.minY {
            clamped.origin.y = visible.minY
        }

        return clamped
    }
}

private struct AmpXLayoutV1DTO: Codable {
    let version: Int
    let order: [String]
    let collapsed: [String]
    let detached: [String]
    let closed: [String]
    let stackFrame: AmpXFrameDTO?
    let detachedFrames: [String: AmpXFrameDTO]?
    let playlistViewportHeight: Double?

    init(layout: AmpXSavedLayout) {
        version = 1
        order = layout.state.order.map(\.rawValue)
        collapsed = layout.state.collapsed.map(\.rawValue).sorted()
        detached = layout.state.detached.map(\.rawValue).sorted()
        closed = layout.state.closed.map(\.rawValue).sorted()
        stackFrame = AmpXFrameDTO(layout.stackFrame)
        detachedFrames = Dictionary(
            uniqueKeysWithValues: layout.detachedFrames.map { ($0.key.rawValue, AmpXFrameDTO($0.value)) }
        )
        playlistViewportHeight = Double(layout.playlistViewportHeight)
    }
}

private struct AmpXFrameDTO: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var cgRect: CGRect? {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite, width > 0, height > 0 else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
