import SwiftUI
import Observation

/// Owns the interaction state for one level so the views stay declarative:
/// what is being dragged, what is selected, and what just happened that the
/// board should react to.
@MainActor
@Observable
final class GameController {
    let session: GameSession
    let drag = DragCoordinator()

    /// Tap-to-select is a full alternative to dragging — it is what makes the
    /// game playable with VoiceOver or one thumb.
    var selected: Tile?
    var hinted: GridPoint?
    /// Bumped on solve; drives the ripple across the board.
    var solveToken = 0
    /// Bumped when a drop is refused; drives a single shake.
    var shakeToken = 0
    /// The cell that most recently received a tile, for its landing bounce.
    var landed: GridPoint?
    var landingToken = 0

    init(puzzle: Puzzle) {
        session = GameSession(puzzle: puzzle)
        drag.slots = Set(puzzle.slots)
    }

    // MARK: - Dragging

    func beginDrag(tile: Tile, from origin: DropTarget, size: CGFloat, at point: CGPoint) {
        guard !session.isSolved else { return }
        selected = nil
        drag.begin(tile: tile, from: origin, size: size, at: point)
        Haptics.play(.pickUp)
    }

    func updateDrag(to point: CGPoint) {
        guard drag.isDragging else { return }
        let before = drag.hover
        drag.update(to: point)
        if drag.hover != before, drag.hover != nil { Haptics.play(.select) }
    }

    func endDrag(at point: CGPoint) {
        guard let payload = drag.payload else { return }
        drag.location = point
        let target = drag.target(at: drag.ghostCentre)

        withAnimation(Motion.settle) {
            // A drop in the margins is a cancel: the tile stays where it was.
            if let target {
                switch target {
                case .slot(let destination):
                    if session.place(payload.tile, at: destination) {
                        land(on: destination)
                    } else {
                        refuse()
                    }
                case .tray:
                    if case .slot = payload.origin {
                        session.returnToTray(payload.tile)
                        Haptics.play(.drop)
                    }
                }
            }
            drag.clear()
        }
    }

    // MARK: - Tapping

    func tap(tile: Tile, from origin: DropTarget) {
        guard !session.isSolved else { return }
        if selected == tile {
            selected = nil
            return
        }
        if let chosen = selected, case .slot(let destination) = origin {
            // Tapping a placed tile while holding another one swaps them.
            withAnimation(Motion.settle) {
                if session.place(chosen, at: destination) { land(on: destination) }
                selected = nil
            }
            return
        }
        selected = tile
        Haptics.play(.select)
    }

    func tap(slot point: GridPoint) {
        guard !session.isSolved else { return }
        guard let chosen = selected else {
            // Tapping a filled slot with nothing held picks that tile up.
            if let occupant = session.tile(at: point) { tap(tile: occupant, from: .slot(point)) }
            return
        }
        withAnimation(Motion.settle) {
            if session.place(chosen, at: point) { land(on: point) } else { refuse() }
            selected = nil
        }
    }

    func returnSelectedToTray() {
        guard let chosen = selected else { return }
        withAnimation(Motion.settle) {
            session.returnToTray(chosen)
            selected = nil
        }
        Haptics.play(.drop)
    }

    // MARK: - Assistance

    func useHint() {
        guard let target = session.revealHint() else { return }
        withAnimation(Motion.settle) {
            hinted = target
            land(on: target)
        }
        Haptics.play(.snap)
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(Motion.quick) { hinted = nil }
        }
    }

    func reset() {
        withAnimation(Motion.settle) {
            session.reset()
            selected = nil
            hinted = nil
        }
        Haptics.play(.drop)
    }

    func celebrate() {
        solveToken += 1
        Haptics.celebrate()
    }

    // MARK: - Feedback

    private func land(on point: GridPoint) {
        landed = point
        landingToken += 1
        Haptics.play(.drop)
    }

    private func refuse() {
        shakeToken += 1
        Haptics.play(.reject)
    }
}
