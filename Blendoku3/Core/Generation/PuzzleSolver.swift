import Foundation

/// Counts how many ways the tray can legally fill the empty cells.
///
/// "Legal" means every run of three or more cells reads as an even blend:
/// the colours along a run form an arithmetic progression in Oklab. Because a
/// progression is pinned down by any two of its terms, knowing two cells in a
/// run determines the whole run — which makes the search collapse fast.
struct PuzzleSolver {
    let cellCount: Int
    /// Maximal runs, as indices into the cell array.
    let runs: [[Int]]
    /// Cells that are already on the board.
    let givens: [Int: BlendColor]
    /// How many cells the player still has to fill.
    let openCount: Int
    /// Tray colours. Must be pairwise distinct by more than `epsilon`.
    let tiles: [BlendColor]
    var epsilon: Double = 1e-7

    /// Number of distinct completions, counted up to `limit`.
    func countSolutions(limit: Int = 2) -> Int {
        var assigned = [BlendColor?](repeating: nil, count: cellCount)
        for (index, colour) in givens { assigned[index] = colour }
        let used = [Bool](repeating: false, count: tiles.count)
        var found = 0
        search(assigned: assigned, used: used, remaining: openCount, limit: limit, found: &found)
        return found
    }

    var hasUniqueSolution: Bool { countSolutions(limit: 2) == 1 }

    private func search(assigned: [BlendColor?], used: [Bool], remaining: Int,
                        limit: Int, found: inout Int) {
        var assigned = assigned
        var used = used
        var remaining = remaining

        // Fixed point: keep completing runs until nothing new can be derived.
        var changed = true
        while changed {
            changed = false
            for run in runs {
                var known: [(position: Int, colour: BlendColor)] = []
                for (position, cell) in run.enumerated() {
                    if let colour = assigned[cell] { known.append((position, colour)) }
                }
                guard known.count >= 2 else { continue }

                let first = known[0]
                let second = known[1]
                let step = (second.colour - first.colour) / Double(second.position - first.position)

                for entry in known.dropFirst(2) {
                    let expected = first.colour + step * Double(entry.position - first.position)
                    if expected.distance(to: entry.colour) > epsilon { return }
                }

                for (position, cell) in run.enumerated() where assigned[cell] == nil {
                    let target = first.colour + step * Double(position - first.position)
                    var match: Int?
                    for (index, tile) in tiles.enumerated() where !used[index] {
                        if tile.distance(to: target) <= epsilon { match = index; break }
                    }
                    guard let match else { return }
                    assigned[cell] = tiles[match]
                    used[match] = true
                    remaining -= 1
                    changed = true
                }
            }
        }

        guard remaining > 0 else {
            found += 1
            return
        }

        // Branch on the cell that will unlock the most: one sitting in the run
        // with the most colours already known.
        var branchCell = -1
        var bestKnown = -1
        for run in runs {
            var knownCount = 0
            var firstOpen = -1
            for cell in run {
                if assigned[cell] == nil {
                    if firstOpen < 0 { firstOpen = cell }
                } else {
                    knownCount += 1
                }
            }
            if firstOpen >= 0, knownCount > bestKnown {
                bestKnown = knownCount
                branchCell = firstOpen
            }
        }
        if branchCell < 0 {
            branchCell = assigned.firstIndex(where: { $0 == nil }) ?? -1
            guard branchCell >= 0 else { found += 1; return }
        }

        for (index, tile) in tiles.enumerated() where !used[index] {
            var nextAssigned = assigned
            var nextUsed = used
            nextAssigned[branchCell] = tile
            nextUsed[index] = true
            search(assigned: nextAssigned, used: nextUsed,
                   remaining: remaining - 1, limit: limit, found: &found)
            if found >= limit { return }
        }
    }
}

extension PuzzleSolver {
    /// Builds a solver for a candidate puzzle: `open` are the cells being
    /// emptied, everything else stays on the board as a clue.
    init(cells: [GridPoint],
         runs: [PuzzleRun],
         solution: [GridPoint: BlendColor],
         open: Set<GridPoint>,
         extraTiles: [BlendColor] = []) {
        var indexOf: [GridPoint: Int] = [:]
        indexOf.reserveCapacity(cells.count)
        for (index, point) in cells.enumerated() { indexOf[point] = index }

        self.cellCount = cells.count
        self.runs = runs.map { run in run.points.compactMap { indexOf[$0] } }

        var givens: [Int: BlendColor] = [:]
        var trayColours: [BlendColor] = []
        for (index, point) in cells.enumerated() {
            guard let colour = solution[point] else { continue }
            if open.contains(point) {
                trayColours.append(colour)
            } else {
                givens[index] = colour
            }
        }
        self.givens = givens
        self.openCount = open.count
        self.tiles = trayColours + extraTiles
    }
}

/// Finds every maximal straight line of three or more cells.
enum RunFinder {
    static func runs(in cells: Set<GridPoint>) -> [PuzzleRun] {
        var result: [PuzzleRun] = []

        for cell in cells.sorted() where !cells.contains(cell.offset(dx: -1, dy: 0)) {
            var points = [cell]
            var cursor = cell.offset(dx: 1, dy: 0)
            while cells.contains(cursor) {
                points.append(cursor)
                cursor = cursor.offset(dx: 1, dy: 0)
            }
            if points.count >= 3 { result.append(PuzzleRun(axis: .horizontal, points: points)) }
        }

        for cell in cells.sorted() where !cells.contains(cell.offset(dx: 0, dy: -1)) {
            var points = [cell]
            var cursor = cell.offset(dx: 0, dy: 1)
            while cells.contains(cursor) {
                points.append(cursor)
                cursor = cursor.offset(dx: 0, dy: 1)
            }
            if points.count >= 3 { result.append(PuzzleRun(axis: .vertical, points: points)) }
        }

        return result
    }
}
