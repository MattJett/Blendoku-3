import Foundation
import Observation

/// Live state of one attempt at a puzzle: where every tile currently sits,
/// which lines already read correctly, and whether the board is finished.
@Observable
final class GameSession {
    let puzzle: Puzzle

    /// Where each movable tile is right now. Missing means "still in the tray".
    private(set) var placement: [Tile.ID: GridPoint] = [:]
    /// The same fact read the other way — which tile is in a cell — kept in
    /// step with `placement` so reading the board is a lookup rather than a
    /// search. The board reads every cell on every frame it draws.
    private(set) var occupant: [GridPoint: Tile.ID] = [:]
    /// When each filled slot last received the tile now in it. A counter
    /// rather than a clock: all the song needs is the order.
    private(set) var stamps: [GridPoint: Int] = [:]
    private(set) var moves = 0
    private(set) var hintsUsed = 0
    private(set) var isSolved = false
    private(set) var solvedAt: Date?
    /// Indices into `puzzle.runs` whose colours currently read as an even blend.
    private(set) var satisfiedRuns: Set<Int> = []
    /// Bumped whenever a drop is rejected, so the view can shake once.
    private(set) var rejectionCount = 0

    /// Tray order is fixed for the whole session so tiles never shuffle
    /// themselves out from under the player's finger.
    let trayOrder: [Tile]

    private let tilesByID: [Tile.ID: Tile]
    private let slotSet: Set<GridPoint>
    private let wanted: [GridPoint: Tile]
    @ObservationIgnored private var tick = 0

    // The clock only runs while the board is actually in front of the player.
    // A timer that kept counting through a phone call, or while the app sat in
    // the background overnight, would make the time on the victory panel a
    // measure of nothing.
    private let now: () -> Date
    @ObservationIgnored private var banked: TimeInterval = 0
    @ObservationIgnored private var runningSince: Date?

    private let tolerance = 1e-6

    init(puzzle: Puzzle, now: @escaping () -> Date = Date.init) {
        self.puzzle = puzzle
        self.trayOrder = puzzle.tiles
        self.now = now
        tilesByID = Dictionary(puzzle.tiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        slotSet = Set(puzzle.slots)
        var wanted: [GridPoint: Tile] = [:]
        for slot in puzzle.slots {
            if let tile = puzzle.solutionTile(for: slot) { wanted[slot] = tile }
        }
        self.wanted = wanted
        runningSince = now()
    }

    // MARK: - Time

    var elapsed: TimeInterval {
        banked + (runningSince.map { max(0, now().timeIntervalSince($0)) } ?? 0)
    }

    var isClockRunning: Bool { runningSince != nil }

    func pauseClock() {
        guard let since = runningSince else { return }
        banked += max(0, now().timeIntervalSince(since))
        runningSince = nil
    }

    func resumeClock() {
        guard runningSince == nil, !isSolved else { return }
        runningSince = now()
    }

    // MARK: - Reading the board

    var remainingCount: Int { puzzle.slots.count - placement.count }

    var progress: Double {
        guard !puzzle.slots.isEmpty else { return 1 }
        return Double(placement.count) / Double(puzzle.slots.count)
    }

    func tile(at point: GridPoint) -> Tile? {
        occupant[point].flatMap { tilesByID[$0] }
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

    /// The placed cells in the order their current tiles went down — the
    /// melody of the song a solved board plays.
    var placementOrder: [GridPoint] {
        stamps.sorted { $0.value < $1.value }.map(\.key)
    }

    // MARK: - Moves

    @discardableResult
    func place(_ tile: Tile, at point: GridPoint) -> Bool {
        guard !isSolved, slotSet.contains(point), tilesByID[tile.id] != nil else {
            rejectionCount += 1
            return false
        }
        if placement[tile.id] == point { return false }

        let origin = placement[tile.id]
        let displaced = occupant[point]

        if let origin { vacate(origin) }
        put(tile.id, at: point)
        // Dropping onto a filled slot swaps if the tile came from the board,
        // and bumps the occupant back to the tray otherwise.
        if let displaced {
            if let origin { put(displaced, at: origin) } else { placement[displaced] = nil }
        }

        moves += 1
        refresh()
        return true
    }

    @discardableResult
    func returnToTray(_ tile: Tile) -> Bool {
        guard !isSolved, let from = placement[tile.id] else { return false }
        placement[tile.id] = nil
        vacate(from)
        moves += 1
        refresh()
        return true
    }

    func reset() {
        placement.removeAll()
        occupant.removeAll()
        stamps.removeAll()
        tick = 0
        moves = 0
        hintsUsed = 0
        isSolved = false
        solvedAt = nil
        satisfiedRuns = []
        banked = 0
        runningSince = now()
    }

    /// Fills in one correct tile: the first slot that is empty or wrong.
    /// Returns where it landed so the view can draw attention to it.
    @discardableResult
    func revealHint() -> GridPoint? {
        guard !isSolved else { return nil }
        guard let target = puzzle.slots.first(where: { !isCorrect(at: $0) }),
              let tile = wanted[target] else { return nil }
        settle(tile, at: target)
        hintsUsed += 1
        moves += 1
        refresh()
        return target
    }

    /// Places every remaining tile correctly. Used by the screenshot and UI
    /// test hooks and by the tests; there is no player-facing button for it.
    func solveCompletely() {
        for slot in puzzle.slots where !isCorrect(at: slot) {
            if let tile = wanted[slot] { settle(tile, at: slot) }
        }
        refresh()
    }

    // MARK: - Resuming

    /// Everything needed to put this board back exactly as it is.
    func snapshot() -> SessionSnapshot {
        let entries = placement.compactMap { id, point -> SessionSnapshot.Entry? in
            guard let stamp = stamps[point] else { return nil }
            return SessionSnapshot.Entry(tile: id, x: point.x, y: point.y, stamp: stamp)
        }
        return SessionSnapshot(arc: puzzle.arc,
                               level: puzzle.level,
                               seed: String(puzzle.seed),
                               entries: entries.sorted { $0.stamp < $1.stamp },
                               moves: moves,
                               hintsUsed: hintsUsed,
                               seconds: elapsed)
    }

    /// Puts a saved board back. Refuses — leaving the session untouched —
    /// anything that does not describe *this* puzzle exactly: a different
    /// level, a board from a generator that has since changed, a tile that
    /// does not exist or sits twice, a slot that is not a slot. The file is
    /// on disk, and anything on disk may have been edited.
    @discardableResult
    func restore(_ saved: SessionSnapshot) -> Bool {
        guard !isSolved, placement.isEmpty,
              saved.version == SessionSnapshot.currentVersion,
              saved.arc == puzzle.arc, saved.level == puzzle.level,
              saved.seed == String(puzzle.seed),
              (0...SessionSnapshot.maximumMoves).contains(saved.moves),
              (0...saved.moves).contains(saved.hintsUsed),
              saved.seconds.isFinite, (0...SessionSnapshot.maximumSeconds).contains(saved.seconds),
              saved.entries.count <= puzzle.slots.count
        else { return false }

        var seenTiles = Set<Tile.ID>()
        var seenPoints = Set<GridPoint>()
        for entry in saved.entries {
            let point = GridPoint(entry.x, entry.y)
            guard tilesByID[entry.tile] != nil, slotSet.contains(point),
                  seenTiles.insert(entry.tile).inserted,
                  seenPoints.insert(point).inserted,
                  entry.stamp >= 0
            else { return false }
        }

        for entry in saved.entries.sorted(by: { $0.stamp < $1.stamp }) {
            put(entry.tile, at: GridPoint(entry.x, entry.y))
        }
        moves = saved.moves
        hintsUsed = saved.hintsUsed
        banked = saved.seconds
        runningSince = now()
        refresh()

        // A finished board is never saved, so one that comes back finished
        // was not written by this game. Start it clean instead.
        if isSolved {
            reset()
            return false
        }
        return true
    }

    // MARK: - Bookkeeping

    private func put(_ id: Tile.ID, at point: GridPoint) {
        placement[id] = point
        occupant[point] = id
        tick += 1
        stamps[point] = tick
    }

    private func vacate(_ point: GridPoint) {
        occupant[point] = nil
        stamps[point] = nil
    }

    /// Moves `tile` into `slot`, sending whatever was there to the tray and
    /// emptying wherever `tile` was before.
    private func settle(_ tile: Tile, at slot: GridPoint) {
        if let current = occupant[slot], current != tile.id { placement[current] = nil }
        if let from = placement[tile.id], from != slot { vacate(from) }
        put(tile.id, at: slot)
    }

    // MARK: - Validation

    private func refresh() {
        var satisfied: Set<Int> = []
        for (index, run) in puzzle.runs.enumerated() where isEvenBlend(run) {
            satisfied.insert(index)
        }
        satisfiedRuns = satisfied

        let complete = occupant.count == puzzle.slots.count
        let wasSolved = isSolved
        isSolved = complete && satisfied.count == puzzle.runs.count
        if isSolved && !wasSolved {
            solvedAt = now()
            pauseClock()
        }
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
