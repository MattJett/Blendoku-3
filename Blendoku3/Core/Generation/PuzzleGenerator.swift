import Foundation

/// Builds a level from nothing but its number.
///
/// The pipeline is: pick a difficulty profile → cut one or more shapes out of
/// the grid → drape an affine colour field over each shape → remove cells one
/// at a time for as long as the puzzle still has exactly one solution → add
/// decoy tiles that provably fit nowhere.
enum PuzzleGenerator {
    static func puzzle(level: Int) -> Puzzle {
        let profile = DifficultyCurve.profile(for: level)
        // Raised from 72 with the steeper curve. The big late boards sit close
        // enough to the edge of the gamut that a seed can legitimately need a
        // hundred tries — level 69 lands on its 130th — and a level that fails
        // to generate is a level that does not exist.
        for attempt in 0..<180 {
            var rng = SplitMix64(seed: .gameSeed(level: level, salt: UInt64(attempt)))
            if let puzzle = build(profile: profile, attempt: attempt, rng: &rng) {
                return puzzle
            }
        }
        return fallback(profile: profile)
    }

    // MARK: - One attempt

    private static func build(profile: DifficultyProfile, attempt: Int, rng: inout SplitMix64) -> Puzzle? {
        let budgets = split(total: profile.targetCells, into: profile.componentCount)
        var shapes: [[GridPoint]] = []
        for budget in budgets {
            let archetype = rng.pick(profile.archetypes)
            let span = archetype.isPlanar ? profile.maxSpan2D : profile.maxSpan
            let shape = archetype.build(budget: budget, maxSpan: span, rng: &rng)
            guard shape.count >= 3 else { return nil }
            shapes.append(ShapeArchetype.orient(shape, variant: rng.nextInt(in: 0...7)))
        }

        guard let placed = pack(shapes: shapes) else { return nil }
        let cellSet = Set(placed.flatMap { $0 })
        guard cellSet.count == placed.reduce(0, { $0 + $1.count }) else { return nil }
        guard cellSet.count <= profile.targetCells + 8 else { return nil }
        let cells = cellSet.sorted()

        // A colour field per shape, hues fanned out so shapes stay tellable apart.
        var solution: [GridPoint: BlendColor] = [:]
        var used: [BlendColor] = []
        let spread = profile.hueSpread * 0.9
        for (index, shape) in placed.enumerated() {
            let centred = Double(index) - Double(placed.count - 1) / 2
            let hueOffset = placed.count > 1 ? centred * spread : 0
            let local = ShapeArchetype.normalise(shape)
            guard let field = ColorFieldFactory.make(points: local, profile: profile,
                                                     hueOffset: hueOffset, avoid: used,
                                                     rng: &rng) else { return nil }
            guard let bounds = GridBounds(points: shape) else { return nil }
            for point in shape {
                let localPoint = GridPoint(point.x - bounds.minX, point.y - bounds.minY)
                let colour = field.colour(at: localPoint)
                solution[point] = colour
                used.append(colour)
            }
        }

        // No two tiles anywhere on the board may look the same.
        let allColours = cells.compactMap { solution[$0] }
        guard ColorFieldFactory.minimumPairDistance(allColours) >= profile.minStep * 0.78 else { return nil }

        let runs = RunFinder.runs(in: cellSet)
        guard !runs.isEmpty else { return nil }

        let wantedSlots = min(profile.targetSlots, max(2, Int(Double(cells.count) * 0.78)))
        let open = dig(cells: cells, runs: runs, solution: solution, target: wantedSlots, rng: &rng)
        guard open.count >= 2, open.count >= wantedSlots - 3 else { return nil }

        let decoys = makeDecoys(count: profile.decoyCount,
                                cells: cells, runs: runs, solution: solution,
                                open: open, profile: profile, rng: &rng)

        var tiles: [Tile] = []
        for point in open.sorted() {
            guard let colour = solution[point] else { return nil }
            tiles.append(Tile(id: tiles.count, color: colour, isDecoy: false))
        }
        for colour in decoys {
            tiles.append(Tile(id: tiles.count, color: colour, isDecoy: true))
        }

        guard let bounds = GridBounds(points: cells) else { return nil }
        return Puzzle(level: profile.level,
                      seed: .gameSeed(level: profile.level, salt: UInt64(attempt)),
                      chapter: profile.chapter,
                      cells: cells,
                      solution: solution,
                      clues: Set(cells).subtracting(open),
                      slots: open.sorted(),
                      runs: runs,
                      tiles: rng.shuffled(tiles),
                      bounds: bounds)
    }

    // MARK: - Shapes on the board

    private static func split(total: Int, into parts: Int) -> [Int] {
        guard parts > 1 else { return [max(3, total)] }
        let base = max(3, total / parts)
        var budgets = Array(repeating: base, count: parts)
        var remainder = total - base * parts
        var index = 0
        while remainder > 0 {
            budgets[index % parts] += 1
            remainder -= 1
            index += 1
        }
        return budgets
    }

    /// Shelf-packs the shapes leaving one empty cell between them, trying a few
    /// board widths and keeping the most phone-shaped result.
    private static func pack(shapes: [[GridPoint]]) -> [[GridPoint]]? {
        guard !shapes.isEmpty else { return nil }
        let ordered = shapes.sorted { lhs, rhs in
            (GridBounds(points: lhs)?.height ?? 0) > (GridBounds(points: rhs)?.height ?? 0)
        }

        var best: [[GridPoint]]?
        var bestScore = Double.infinity

        for maxWidth in 3...10 {
            var placed: [[GridPoint]] = []
            var cursorX = 0
            var shelfY = 0
            var shelfHeight = 0
            var overflowed = false

            for shape in ordered {
                guard let bounds = GridBounds(points: shape) else { return nil }
                if cursorX > 0 && cursorX + bounds.width > maxWidth {
                    shelfY += shelfHeight + 1
                    cursorX = 0
                    shelfHeight = 0
                }
                if bounds.width > maxWidth { overflowed = true }
                placed.append(shape.map { GridPoint($0.x + cursorX, $0.y + shelfY) })
                cursorX += bounds.width + 1
                shelfHeight = max(shelfHeight, bounds.height)
            }
            if overflowed { continue }

            guard let bounds = GridBounds(points: placed.flatMap { $0 }) else { continue }
            guard bounds.width <= 11, bounds.height <= 15 else { continue }
            let aspect = Double(bounds.width) / Double(bounds.height)
            let score = abs(aspect - 0.82) + Double(bounds.width) * 0.015
            if score < bestScore {
                bestScore = score
                best = placed
            }
        }

        guard let best else { return nil }
        guard let bounds = GridBounds(points: best.flatMap { $0 }) else { return nil }
        return best.map { shape in shape.map { GridPoint($0.x - bounds.minX, $0.y - bounds.minY) } }
    }

    // MARK: - Carving out the empty cells

    /// Empties cells one by one, keeping only the removals that leave the
    /// puzzle with exactly one solution. Same idea as digging a sudoku.
    private static func dig(cells: [GridPoint],
                            runs: [PuzzleRun],
                            solution: [GridPoint: BlendColor],
                            target: Int,
                            rng: inout SplitMix64) -> Set<GridPoint> {
        var open: Set<GridPoint> = []
        for point in rng.shuffled(cells) {
            if open.count >= target { break }
            var candidate = open
            candidate.insert(point)
            let solver = PuzzleSolver(cells: cells, runs: runs, solution: solution, open: candidate)
            if solver.countSolutions(limit: 2) == 1 { open = candidate }
        }
        return open
    }

    // MARK: - Decoys

    /// Extra tray tiles that look like they might belong. Each one is checked
    /// against the solver, so a decoy can never create a second solution.
    private static func makeDecoys(count: Int,
                                   cells: [GridPoint],
                                   runs: [PuzzleRun],
                                   solution: [GridPoint: BlendColor],
                                   open: Set<GridPoint>,
                                   profile: DifficultyProfile,
                                   rng: inout SplitMix64) -> [BlendColor] {
        guard count > 0 else { return [] }
        let boardColours = cells.compactMap { solution[$0] }
        guard !boardColours.isEmpty else { return [] }

        var decoys: [BlendColor] = []
        var attempts = 0
        while decoys.count < count && attempts < 400 {
            attempts += 1
            let anchor = rng.pick(boardColours)
            let elevation = rng.nextDouble(in: -1.3...1.3)
            let theta = rng.nextDouble(in: 0...(2 * .pi))
            let direction = BlendColor(l: sin(elevation),
                                       a: cos(elevation) * cos(theta),
                                       b: cos(elevation) * sin(theta))
            let candidate = anchor + direction * rng.nextDouble(in: (profile.minStep * 1.15)...(profile.minStep * 2.6))

            guard candidate.isDisplayable(margin: 0.018),
                  candidate.l > 0.14, candidate.l < 0.92,
                  candidate.chroma <= profile.maxCellChroma else { continue }

            let separation = profile.minStep * 1.02
            guard boardColours.allSatisfy({ $0.distance(to: candidate) >= separation }),
                  decoys.allSatisfy({ $0.distance(to: candidate) >= separation }) else { continue }

            let solver = PuzzleSolver(cells: cells, runs: runs, solution: solution,
                                      open: open, extraTiles: decoys + [candidate])
            guard solver.countSolutions(limit: 2) == 1 else { continue }
            decoys.append(candidate)
        }
        return decoys
    }

    // MARK: - Safety net

    /// A plain five-cell row. Only reached if every attempt above failed, which
    /// the level tests assert never happens — but shipping a crash is worse.
    private static func fallback(profile: DifficultyProfile) -> Puzzle {
        let cells = (0..<5).map { GridPoint($0, 0) }
        let start = BlendColor(lightness: 0.34, chroma: 0.09, hue: profile.baseHue)
        let end = BlendColor(lightness: 0.80, chroma: 0.09, hue: profile.baseHue)
        var solution: [GridPoint: BlendColor] = [:]
        for (index, point) in cells.enumerated() {
            solution[point] = BlendColor.mix(start, end, Double(index) / 4)
        }
        let open: Set<GridPoint> = [cells[1], cells[3]]
        let tiles = open.sorted().enumerated().map { index, point in
            Tile(id: index, color: solution[point]!, isDecoy: false)
        }
        return Puzzle(level: profile.level,
                      seed: .gameSeed(level: profile.level, salt: 999),
                      chapter: profile.chapter,
                      cells: cells,
                      solution: solution,
                      clues: Set(cells).subtracting(open),
                      slots: open.sorted(),
                      runs: RunFinder.runs(in: Set(cells)),
                      tiles: tiles,
                      bounds: GridBounds(points: cells)!)
    }
}
