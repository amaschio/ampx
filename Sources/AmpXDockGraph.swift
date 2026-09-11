import CoreGraphics

/// A node in the docking graph: either the root main player or a managed panel.
enum AmpXDockNode: Hashable {
    case main
    case panel(AmpXPanelID)
}

/// Pure, geometry-primary docking resolution.
///
/// In the geometry-primary model the window *positions* are the source of truth and the dock
/// structure is **derived** from them — there is no stored order or tree. This reconstructs the
/// parent/child spanning tree (rooted at the main window) from the current frames, so the manager
/// can mirror it onto AppKit `addChildWindow` links and so panels not connected to the main cluster
/// are reported as floating.
///
/// Free of AppKit so it is unit-testable without live windows (the manager passes frames in). The
/// adjacency test is the existing 2D Webamp port `AmpXWindowSnap.abuts`, so left/right docking
/// works exactly like top/bottom.
enum AmpXDockGraph {
    /// BFS spanning tree from `.main`: each window adopts as parent the first abutting window
    /// discovered closer to the root. `order` makes the traversal deterministic when a panel abuts
    /// more than one window (earlier-ordered neighbors win), matching the registry's preference.
    ///
    /// - Returns: each docked panel mapped to its parent node. Panels absent from the result are
    ///   not connected to the main cluster (i.e. floating).
    static func parents(
        frames: [AmpXDockNode: CGRect],
        order: [AmpXPanelID]
    ) -> [AmpXPanelID: AmpXDockNode] {
        let traversal: [AmpXDockNode] = [.main] + order.map(AmpXDockNode.panel)

        var parents: [AmpXPanelID: AmpXDockNode] = [:]
        var visited: Set<AmpXDockNode> = [.main]
        var queue: [AmpXDockNode] = [.main]

        while !queue.isEmpty {
            let node = queue.removeFirst()
            guard let nodeFrame = frames[node] else { continue }
            let nodeBox = AmpXWindowSnap.Box(frame: nodeFrame)

            for candidate in traversal where !visited.contains(candidate) {
                guard case let .panel(id) = candidate, let frame = frames[candidate] else { continue }
                if AmpXWindowSnap.abuts(nodeBox, AmpXWindowSnap.Box(frame: frame)) {
                    parents[id] = node
                    visited.insert(candidate)
                    queue.append(candidate)
                }
            }
        }

        return parents
    }

    /// Panels in `order` that are not connected to the main cluster, given the derived parents.
    static func floating(
        order: [AmpXPanelID],
        parents: [AmpXPanelID: AmpXDockNode]
    ) -> Set<AmpXPanelID> {
        Set(order.filter { parents[$0] == nil })
    }

    /// Panels whose dock ancestry includes `ancestor` (the panel itself is not returned).
    static func descendants(
        of ancestor: AmpXPanelID,
        parents: [AmpXPanelID: AmpXDockNode]
    ) -> [AmpXPanelID] {
        parents.keys.filter { id in
            self.isDescendant(id, of: ancestor, parents: parents)
        }
    }

    private static func isDescendant(
        _ id: AmpXPanelID,
        of ancestor: AmpXPanelID,
        parents: [AmpXPanelID: AmpXDockNode]
    ) -> Bool {
        var current: AmpXPanelID? = id
        var steps = 0
        while let node = current, steps < parents.count + 1 {
            switch parents[node] {
            case let .panel(parent) where parent == ancestor:
                return true
            case let .panel(parent):
                current = parent
                steps += 1
            case .main, nil:
                return false
            }
        }
        return false
    }
}
