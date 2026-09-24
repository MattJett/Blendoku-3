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
    /// Which corners of each cell round off. Fixed for the whole level, so
    /// worked out once here rather than for every cell on every frame.
    let corners: [GridPoint: TileCorners]
    /// The instrument this board plays, fixed by its palette.
    let warmth: Double

    /// Tap-to-select is a full alternative to dragging — it is what makes the
    /// game playable with VoiceOver or one thumb.
    var selected: Tile?
    var hinted: GridPoint?
    /// The pause menu is up. The clock stops with it.
    private(set) var isPaused = false
    /// Bumped on solve; drives the ripple across the board.
    var solveToken = 0
    /// Bumped when a drop is refused; drives a single shake.
    var shakeToken = 0
    /// The cell that most recently received a tile, for its landing bounce.
    var landed: GridPoint?
    var landingToken = 0

    /// The song being played back over the solved board, and when each cell
    /// lights during it.
    private(set) var replay: SongSchedule?
    private(set) var pulses: [GridPoint: SongSchedule.Pulse] = [:]
    /// Bumped at the instant the song starts, so the board lights in time
    /// with the sound rather than with the tap that solved it.
    private(set) var replayToken = 0

    init(puzzle: Puzzle, warmth: Double = 0.5) {
        session = GameSession(puzzle: puzzle)
        drag.slots = Set(puzzle.slots)
        self.warmth = warmth
        let occupied = Set(puzzle.cells)
        corners = Dictionary(puzzle.cells.map { ($0, BoardView.corners(at: $0, in: occupied)) },
                             uniquingKeysWith: { first, _ in first })
    }

    /// Whether anything should respond to a touch on the board.
    var isInteractive: Bool { !session.isSolved && !isPaused }

    // MARK: - Pausing

    func pause() {
        guard !isPaused, !session.isSolved else { return }
        drag.clear()
        selected = nil
        isPaused = true
        session.pauseClock()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        session.resumeClock()
    }

    // MARK: - Dragging

    func beginDrag(tile: Tile, from origin: DropTarget, size: CGFloat, at point: CGPoint) {
        guard isInteractive else { return }
        selected = nil
        drag.begin(tile: tile, from: origin, size: size, at: point)
        Haptics.play(.pickUp)
        SoundField.shared.play(.pickUp, for: tile.color)
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
            if let target, isInteractive {
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
        guard isInteractive else { return }
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
        SoundField.shared.play(.pickUp, for: tile.color)
    }

    func tap(slot point: GridPoint) {
        guard isInteractive else { return }
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
        guard isInteractive, let chosen = selected else { return }
        withAnimation(Motion.settle) {
            session.returnToTray(chosen)
            selected = nil
        }
        Haptics.play(.drop)
    }

    // MARK: - Assistance

    func useHint() {
        guard isInteractive, let target = session.revealHint() else { return }
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
            replay = nil
            pulses = [:]
            isPaused = false
        }
        Haptics.play(.drop)
    }

    func celebrate() {
        solveToken += 1
        Haptics.celebrate()
    }

    // MARK: - The song

    /// The song this board makes, in the order it was actually played.
    func song() -> SongSchedule {
        SongSchedule(puzzle: session.puzzle, order: session.placementOrder) { point in
            self.session.colour(at: point)
        }
    }

    /// Starts lighting the board to `schedule`. Called at the moment the
    /// sound starts.
    func beginReplay(_ schedule: SongSchedule) {
        replay = schedule
        pulses = schedule.pulses()
        replayToken += 1
    }

    func endReplay() {
        replay = nil
    }

    // MARK: - Feedback

    private func land(on point: GridPoint) {
        landed = point
        landingToken += 1
        Haptics.play(.drop)

        // The board is what decides whether this rings or wavers. `place`
        // already succeeded — the slot was legal — so the only question left is
        // whether this is the colour that belongs in it, which is exactly the
        // judgement the game is asking for and exactly what the ear now hears.
        if let colour = session.colour(at: point) {
            SoundField.shared.play(session.isCorrect(at: point) ? .settled : .unsettled,
                                   for: colour)
        }
    }

    private func refuse() {
        shakeToken += 1
        Haptics.play(.reject)
    }
}
