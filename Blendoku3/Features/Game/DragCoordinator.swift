import SwiftUI
import Observation

/// Somewhere a dragged tile can be dropped.
enum DropTarget: Hashable {
    case slot(GridPoint)
    case tray
}

/// Where the board is on screen and how big its cells are. Published once by
/// `BoardView`; everything else derives slot positions arithmetically rather
/// than measuring every cell.
struct BoardPlacement: Equatable {
    var frame: CGRect = .zero
    var step: CGFloat = 0
    var tile: CGFloat = 0
    /// Centre of cell (0, 0), relative to `frame`.
    var firstCentre: CGPoint = .zero

    func centre(of point: GridPoint) -> CGPoint {
        CGPoint(x: frame.minX + firstCentre.x + CGFloat(point.x) * step,
                y: frame.minY + firstCentre.y + CGFloat(point.y) * step)
    }

    /// Nearest grid coordinate to a point in the shared coordinate space.
    func gridPoint(near point: CGPoint) -> (point: GridPoint, distance: CGFloat)? {
        guard step > 0 else { return nil }
        let localX = point.x - frame.minX - firstCentre.x
        let localY = point.y - frame.minY - firstCentre.y
        let column = Int((localX / step).rounded())
        let row = Int((localY / step).rounded())
        let candidate = GridPoint(column, row)
        let centre = self.centre(of: candidate)
        let distance = hypot(point.x - centre.x, point.y - centre.y)
        return (candidate, distance)
    }
}

struct BoardPlacementKey: PreferenceKey {
    static var defaultValue: BoardPlacement { BoardPlacement() }
    static func reduce(value: inout BoardPlacement, nextValue: () -> BoardPlacement) {
        let next = nextValue()
        if next.step > 0 { value = next }
    }
}

struct TrayFrameKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Tracks the tile currently under the player's finger.
///
/// The dragged tile is drawn once in an overlay rather than moved in place, so
/// it can float above the board without the layout fighting the gesture.
@MainActor
@Observable
final class DragCoordinator {
    struct Payload: Equatable {
        var tile: Tile
        var origin: DropTarget
        var size: CGFloat
    }

    var payload: Payload?
    var location: CGPoint = .zero
    var hover: DropTarget?

    @ObservationIgnored var board = BoardPlacement()
    @ObservationIgnored var trayFrame: CGRect = .zero
    @ObservationIgnored var slots: Set<GridPoint> = []

    var isDragging: Bool { payload != nil }

    /// The tile rides a little above the finger so it stays visible, and drops
    /// where it is drawn rather than where the fingertip is.
    var ghostCentre: CGPoint {
        CGPoint(x: location.x, y: location.y - (payload?.size ?? 0) * 0.62)
    }

    func begin(tile: Tile, from origin: DropTarget, size: CGFloat, at point: CGPoint) {
        payload = Payload(tile: tile, origin: origin, size: size)
        location = point
        hover = target(at: ghostCentre)
    }

    func update(to point: CGPoint) {
        location = point
        let next = target(at: ghostCentre)
        if next != hover { hover = next }
    }

    func clear() {
        payload = nil
        hover = nil
    }

    /// Resolves where a drop lands: the slot under the finger, a nearby slot if
    /// the aim was close, or the tray.
    func target(at point: CGPoint) -> DropTarget? {
        if let nearest = board.gridPoint(near: point), slots.contains(nearest.point) {
            // Generous but not silly: within about two thirds of a cell.
            if nearest.distance <= board.step * 0.68 { return .slot(nearest.point) }
        }
        if trayFrame.contains(point) { return .tray }
        return nil
    }
}
