import AppKit

struct AmpXDropGeometry {
    var bounds: CGRect
    var orderedFrames: [(AmpXModuleID, CGRect)]
}

enum AmpXModuleDragController {
    static let tearOffThreshold: CGFloat = 40
    static let settleDuration: TimeInterval = 0.175
    static let insertionMarkerHeight: CGFloat = 2
    static let autoScrollEdgeInset: CGFloat = 24
    static let autoScrollMaxSpeed: CGFloat = 8

    static func dropIndex(geometry: AmpXDropGeometry, point: CGPoint) -> Int? {
        guard geometry.bounds.contains(point) else { return nil }
        guard !geometry.orderedFrames.isEmpty else { return 0 }

        for (index, frame) in geometry.orderedFrames.enumerated() {
            if point.y < frame.1.midY {
                return index
            }
        }

        return geometry.orderedFrames.count
    }

    static func fullOrderIndex(
        forVisibleDropIndex dropIndex: Int,
        excluding draggedID: AmpXModuleID,
        in state: AmpXModuleOrder
    ) -> Int {
        let visible = state.order.filter {
            !state.closed.contains($0) && !state.detached.contains($0) && $0 != draggedID
        }
        let clamped = max(0, min(dropIndex, visible.count))

        if clamped == 0 {
            return state.order.firstIndex(where: {
                !state.closed.contains($0) && !state.detached.contains($0) && $0 != draggedID
            }) ?? 0
        }

        if clamped >= visible.count {
            if let last = visible.last, let lastIndex = state.order.firstIndex(of: last) {
                return lastIndex + 1
            }
            return state.order.count
        }

        let anchor = visible[clamped - 1]
        return (state.order.firstIndex(of: anchor) ?? state.order.count - 1) + 1
    }
}

@MainActor
final class AmpXModuleDragSession {
    private weak var coordinator: AmpXHostCoordinator?
    private weak var viewport: AmpXStackViewport?

    private(set) var isDragging = false
    private var draggedModuleID: AmpXModuleID?
    private var didTearOff = false
    private var autoScrollTimer: Timer?
    private var pendingDropIndex: Int?
    private var lastDragScreenPoint: NSPoint?

    func bind(coordinator: AmpXHostCoordinator, viewport: AmpXStackViewport? = nil) {
        self.coordinator = coordinator
        if let viewport {
            self.viewport = viewport
        }
    }

    func bind(viewport: AmpXStackViewport) {
        self.viewport = viewport
    }

    func beginGripDrag(moduleID: AmpXModuleID, event: NSEvent) {
        guard let window = event.window else { return }
        self.isDragging = true
        self.draggedModuleID = moduleID
        self.didTearOff = self.coordinator?.state.detached.contains(moduleID) ?? false
        self.pendingDropIndex = nil
        self.updateDrag(event: event, in: window)
    }

    func updateDrag(event: NSEvent) {
        guard self.isDragging, let window = event.window else { return }
        self.updateDrag(event: event, in: window)
    }

    func endDrag(event: NSEvent) {
        defer { cancelDrag() }

        guard self.isDragging,
              let moduleID = draggedModuleID,
              let coordinator,
              let window = event.window
        else { return }

        let dropIndex = self.pendingDropIndex
        let overStack = self.isPointOverStack(event.locationInWindow, window: window)

        if self.didTearOff {
            if overStack, let dropIndex {
                coordinator.redock(moduleID, at: dropIndex)
            } else {
                coordinator.updateDetachedFrame(
                    moduleID,
                    frame: self.detachedFrame(anchoredTo: event.locationInWindow, in: window, moduleID: moduleID)
                )
            }
            self.settleLayout(on: coordinator)
            return
        }

        if self.shouldTearOff(event: event) {
            guard moduleID != .player else { return }

            let inheritedWidth = coordinator.stackWindow?.frame.width ?? AmpXMetrics.compositionWidth
            coordinator.detach(
                moduleID,
                at: self.screenPoint(for: event.locationInWindow, in: window),
                inheritedWidth: inheritedWidth
            )
            self.didTearOff = true
            coordinator.updateDetachedFrame(
                moduleID,
                frame: self.detachedFrame(anchoredTo: event.locationInWindow, in: window, moduleID: moduleID)
            )
            self.settleLayout(on: coordinator)
            return
        }

        if overStack, let dropIndex {
            coordinator.reorder(moduleID, toVisibleDropIndex: dropIndex)
            self.settleLayout(on: coordinator)
        }
    }

    func cancelDrag() {
        self.stopAutoScroll()
        self.viewport?.stackView.setInsertionMarker(at: nil, width: 0)
        self.isDragging = false
        self.draggedModuleID = nil
        self.didTearOff = false
        self.pendingDropIndex = nil
        self.lastDragScreenPoint = nil
    }

    func cancelDragIfDragging(moduleID: AmpXModuleID) {
        guard self.isDragging, self.draggedModuleID == moduleID else { return }
        self.cancelDrag()
    }

    private func updateDrag(event: NSEvent, in window: NSWindow) {
        guard let moduleID = draggedModuleID,
              let coordinator,
              let viewport
        else { return }

        if self.didTearOff {
            coordinator.updateDetachedFrame(
                moduleID,
                frame: self.detachedFrame(anchoredTo: event.locationInWindow, in: window, moduleID: moduleID)
            )
        }

        if self.shouldTearOff(event: event), moduleID != .player, !self.didTearOff {
            let inheritedWidth = coordinator.stackWindow?.frame.width ?? AmpXMetrics.compositionWidth
            coordinator.detach(
                moduleID,
                at: screenPoint(for: event.locationInWindow, in: window),
                inheritedWidth: inheritedWidth
            )
            self.didTearOff = true
            coordinator.updateDetachedFrame(
                moduleID,
                frame: self.detachedFrame(anchoredTo: event.locationInWindow, in: window, moduleID: moduleID)
            )
        }

        let screenPoint = screenPoint(for: event.locationInWindow, in: window)
        self.lastDragScreenPoint = screenPoint

        guard self.isPointOverStack(screenPoint: screenPoint) else {
            self.pendingDropIndex = nil
            viewport.stackView.setInsertionMarker(at: nil, width: 0)
            self.stopAutoScroll()
            return
        }

        let contentPoint = viewport.stackContentPoint(fromScreenPoint: screenPoint)
        let geometry = coordinator.makeDropGeometry(excluding: moduleID)
        self.pendingDropIndex = AmpXModuleDragController.dropIndex(geometry: geometry, point: contentPoint)
        self.updateInsertionMarker(for: geometry, dropIndex: self.pendingDropIndex)
        self.updateAutoScroll(for: screenPoint)
    }

    private func updateInsertionMarker(for geometry: AmpXDropGeometry, dropIndex: Int?) {
        guard let viewport, let dropIndex else {
            self.viewport?.stackView.setInsertionMarker(at: nil, width: 0)
            return
        }

        let markerY: CGFloat
        if dropIndex >= geometry.orderedFrames.count {
            if let last = geometry.orderedFrames.last {
                markerY = last.1.maxY
            } else {
                markerY = 0
            }
        } else if dropIndex == 0 {
            markerY = geometry.orderedFrames.first?.1.minY ?? 0
        } else {
            let previous = geometry.orderedFrames[dropIndex - 1].1
            let next = geometry.orderedFrames[dropIndex].1
            markerY = (previous.maxY + next.minY) / 2
        }

        viewport.stackView.setInsertionMarker(at: markerY, width: geometry.bounds.width)
    }

    private func updateAutoScroll(for screenPoint: NSPoint) {
        guard let viewport else { return }

        let viewportPoint = viewport.viewportPoint(fromScreenPoint: screenPoint)
        let speed = viewport.autoScrollSpeed(for: viewportPoint)
        guard speed != 0 else {
            self.stopAutoScroll()
            return
        }

        if self.autoScrollTimer == nil {
            self.autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.performAutoScrollTick()
                }
            }
        }

        viewport.pendingAutoScrollSpeed = speed
    }

    private func performAutoScrollTick() {
        guard let viewport,
              let moduleID = draggedModuleID,
              let coordinator,
              viewport.pendingAutoScrollSpeed != 0
        else { return }

        viewport.setScrollOffset(viewport.scrollOffset + viewport.pendingAutoScrollSpeed)

        guard let lastDragScreenPoint else { return }

        let contentPoint = viewport.stackContentPoint(fromScreenPoint: lastDragScreenPoint)
        let geometry = coordinator.makeDropGeometry(excluding: moduleID)
        self.pendingDropIndex = AmpXModuleDragController.dropIndex(geometry: geometry, point: contentPoint)
        self.updateInsertionMarker(for: geometry, dropIndex: self.pendingDropIndex)
    }

    private func stopAutoScroll() {
        self.autoScrollTimer?.invalidate()
        self.autoScrollTimer = nil
        self.viewport?.pendingAutoScrollSpeed = 0
    }

    private func shouldTearOff(event: NSEvent) -> Bool {
        guard let viewport else { return false }
        let viewportPoint = viewport.convert(event.locationInWindow, from: nil)
        let expanded = viewport.bounds.insetBy(
            dx: -AmpXModuleDragController.tearOffThreshold,
            dy: -AmpXModuleDragController.tearOffThreshold
        )
        return !expanded.contains(viewportPoint)
    }

    private func isPointOverStack(screenPoint: NSPoint) -> Bool {
        self.viewport?.contains(screenPoint: screenPoint) ?? false
    }

    private func isPointOverStack(_ windowPoint: NSPoint, window: NSWindow) -> Bool {
        self.isPointOverStack(screenPoint: window.convertPoint(toScreen: windowPoint))
    }

    private func screenPoint(for windowPoint: NSPoint, in window: NSWindow) -> CGPoint {
        let windowPoint = window.convertPoint(toScreen: windowPoint)
        return CGPoint(x: windowPoint.x, y: windowPoint.y)
    }

    private func detachedFrame(
        anchoredTo windowPoint: NSPoint,
        in window: NSWindow,
        moduleID: AmpXModuleID
    ) -> CGRect {
        let screenPoint = self.screenPoint(for: windowPoint, in: window)
        let width = self.coordinator?.detachedWindowFrame(for: moduleID)?.width ?? AmpXMetrics.compositionWidth
        let height = self.coordinator?.detachedWindowFrame(for: moduleID)?.height ?? 300
        return CGRect(
            x: screenPoint.x - width / 2,
            y: screenPoint.y - AmpXMetrics.headerHeight,
            width: width,
            height: height
        )
    }

    private func settleLayout(on coordinator: AmpXHostCoordinator) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AmpXModuleDragController.settleDuration
            coordinator.stackWindowController?.updateLayout()
        }
    }
}
