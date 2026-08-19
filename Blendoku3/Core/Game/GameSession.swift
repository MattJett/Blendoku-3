import Foundation
import Observation

/// Live state of one attempt at a puzzle: where every tile currently sits,
/// which lines already read correctly, and whether the board is finished.
@Observable
final class GameSession {
    let puzzle: Puzzle

    /// Where each movable tile is right now. Missing means "still in the tray".
    private(set) var placement: [Tile.ID: GridPoint] = [:]
    private(set) var moves = 0
    private(set) var hintsUsed = 0
    private(set) var isSolved = false
    private(set) var solvedAt: Date?
    private(set) var startedAt = Date()
    /// Indices into `puzzle.runs` whose colours currently read as an even blend.
    private(set) var satisfiedRuns: Set<Int> = []
    /// Bumped whenever a drop is rejected, so the view can shake once.
    private(set) var rejectionCount = 0

    /// Tray order is fixed for the whole session so tiles never shuffle
    /// themselves out from under the player's finger.
    let trayOrder: [Tile]

    private let tolerance = 1e-6

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.trayOrder = puzzle.tiles
    }

    var elapsed: TimeInterval { (solvedAt ?? Date()).timeIntervalSince(startedAt) }

    var remainingCount: Int { puzzle.slots.count - placement.count }

    var progress: Double {
        guard !puzzle.slots.isEmpty else { return 1 }
        return Double(placement.count) / Double(puzzle.slots.count)
    }

    // MARK: - Reading the board

    func tile(at point: GridPoint) -> Tile? {
        guard let id = placement.first(where: { $0.value == point })?.key else { return nil }
        return trayOrder.first { $0.id == id }
    }

    /// The colour shown at a cell — a clue, a placed tile, or nothing.
    func colour(at point: GridPoint) -> BlendColor? {
        if puzzle.clues.contains(point) { return puzzle.solution[point] }
        return tile(at: point)?.color
    }

    func isInTray(_ tile: Tile) -> Bool { placement[tile.id] == nil }

    func isCorrect(at point: GridPoint) -> Bool {
        guard let colour = colour(at: point), let expected = puzzle.solution[point] else { return false }
        return colour.distance(to: expected) <= tolerance
    }

    // MARK: - Moves

    @discardableResult
    func place(_ tile: Tile, at point: GridPoint) -> Bool {
        guard !isSolved, puzzle.slots.contains(point) else {
            rejectionCount += 1
            return false
        }
        if placement[tile.id] == point { return false }

        let origin = placement[tile.id]
        if let occupant = self.tile(at: point), occupant.id != tile.id {
            // Dropping onto a filled slot swaps if the tile came from the
            // board, and bumps the occupant back to the tray otherwise.
            placement[occupant.id] = origin
        }
        placement[tile.id] = point
        moves += 1
        refresh()
        return true
    }

    @discardableResult
    func returnToTray(_ tile: Tile) -> Bool {
        guard !isSolved, placement[tile.id] != nil else { return false }
        placement[tile.id] = nil
        moves += 1
        refresh()
        return true
    }

    func reset() {
        placement.removeAll()
        moves = 0
        hintsUsed = 0
        isSolved = false
        solvedAt = nil
        startedAt = Date()
        satisfiedRuns = []
    }

    /// Fills in one correct tile: the first slot that is empty or wrong.
    /// Returns where it landed so the view can draw attention to it.
    @discardableResult
    func revealHint() -> GridPoint? {
        guard !isSolved else { return nil }
        let target = puzzle.slots.first { !isCorrect(at: $0) }
        guard let target, let wanted = puzzle.solutionTile(for: target) else { return nil }

        if let occupant = tile(at: target), occupant.id != wanted.id {
            placement[occupant.id] = nil
        }
        placement[wanted.id] = target
        hintsUsed += 1
        moves += 1
        refresh()
        return target
    }

    /// Places every remaining tile correctly. Used by the tutorial's demo and
    /// by the tests; there is no player-facing button for it.
    func solveCompletely() {
        for point in puzzle.slots {
            guard let wanted = puzzle.solutionTile(for: point) else { continue }
            if let occupant = tile(at: point), occupant.id != wanted.id {
                placement[occupant.id] = nil
            }
            placement[wanted.id] = point
        }
        refresh()
    }

    // MARK: - Validation

    private func refresh() {
        var satisfied: Set<Int> = []
        for (index, run) in puzzle.runs.enumerated() where isEvenBlend(run) {
            satisfied.insert(index)
        }
        satisfiedRuns = satisfied

        let complete = placement.count == puzzle.slots.count
            && puzzle.slots.allSatisfy { colour(at: $0) != nil }
        let wasSolved = isSolved
        isSolved = complete && satisfied.count == puzzle.runs.count
        if isSolved && !wasSolved { solvedAt = Date() }
    }

    /// True when every colour along the run is filled in and the steps between
    /// them are equal — which is exactly what "an even blend" means.
    private func isEvenBlend(_ run: PuzzleRun) -> Bool {
        let colours = run.points.compactMap { colour(at: $0) }
        guard colours.count == run.points.count, colours.count >= 3 else { return false }
        let step = (colours[colours.count - 1] - colours[0]) / Double(colours.count - 1)
        for index in 1..<(colours.count - 1) {
            let expected = colours[0] + step * Double(index)
            if expected.distance(to: colours[index]) > tolerance * 10 { return false }
        }
        return true
    }
}
