import Foundation

/// The silhouettes a puzzle can be cut from. Every archetype produces a
/// connected set of cells whose straight runs are the gradients the player
/// has to complete.
enum ShapeArchetype: String, CaseIterable, Sendable {
    case row, column, elbow, tee, cross, staircase, block, frame
    case ladder, comb, hbar, ubar, spiral, plusGrid, diamond

    /// True for shapes that carry a gradient along both axes at once.
    var isPlanar: Bool {
        switch self {
        case .row, .column: false
        default: true
        }
    }

    /// Builds the shape, normalised so its bounding box starts at (0, 0).
    /// `budget` is the wanted cell count; the result may be a little off.
    func build(budget: Int, maxSpan: Int, rng: inout SplitMix64) -> [GridPoint] {
        let span = max(3, maxSpan)
        let budget = max(3, budget)
        let points: [GridPoint]

        switch self {
        case .row:
            points = (0..<clamp(budget, span)).map { GridPoint($0, 0) }

        case .column:
            points = (0..<clamp(budget, span)).map { GridPoint(0, $0) }

        case .elbow:
            let arm = clamp(rng.nextInt(in: 3...max(3, budget - 2)), span)
            let leg = clamp(budget - arm + 1, span)
            points = (0..<arm).map { GridPoint($0, 0) }
                + (1..<leg).map { GridPoint(arm - 1, $0) }

        case .tee:
            let arm = clamp(rng.nextInt(in: 3...max(3, budget - 2)), span)
            let leg = clamp(budget - arm + 1, span)
            let junction = arm / 2
            points = (0..<arm).map { GridPoint($0, 0) }
                + (1..<leg).map { GridPoint(junction, $0) }

        case .cross:
            let arm = clamp(rng.nextInt(in: 3...max(3, budget / 2 + 2)), span)
            let leg = clamp(budget - arm + 1, span)
            let row = leg / 2
            let column = arm / 2
            var set = Set((0..<arm).map { GridPoint($0, row) })
            set.formUnion((0..<leg).map { GridPoint(column, $0) })
            points = Array(set)

        case .staircase:
            points = Self.buildStaircase(budget: budget, span: span, rng: &rng)

        case .block:
            let height = clamp2(Int(Double(budget).squareRoot().rounded()), span)
            let width = clamp2((budget + height - 1) / height, span)
            points = (0..<height).flatMap { y in (0..<width).map { GridPoint($0, y) } }

        case .frame:
            let height = clamp(rng.nextInt(in: 3...max(3, span - 1)), span)
            let width = clamp((budget + 4) / 2 - height, span)
            points = Self.buildFrame(width: width, height: height)

        case .ladder:
            let width = clamp((budget - 2) / 2, span)
            var set = Set((0..<width).map { GridPoint($0, 0) })
            set.formUnion((0..<width).map { GridPoint($0, 2) })
            set.insert(GridPoint(0, 1))
            set.insert(GridPoint(width - 1, 1))
            if width >= 5 { set.insert(GridPoint(width / 2, 1)) }
            points = Array(set)

        case .comb:
            let width = clamp(budget / 2 + 1, span)
            var set = Set((0..<width).map { GridPoint($0, 0) })
            for x in stride(from: 0, to: width, by: 2) {
                set.insert(GridPoint(x, 1))
                set.insert(GridPoint(x, 2))
            }
            points = Array(set)

        case .hbar:
            let height = clamp(rng.nextInt(in: 3...max(3, (budget - 1) / 2)), span)
            var set = Set((0..<height).map { GridPoint(0, $0) })
            set.formUnion((0..<height).map { GridPoint(2, $0) })
            set.insert(GridPoint(1, height / 2))
            points = Array(set)

        case .ubar:
            let height = clamp(rng.nextInt(in: 3...max(3, budget / 2)), span)
            let width = clamp(budget - 2 * height + 2, span)
            var set = Set((0..<height).map { GridPoint(0, $0) })
            set.formUnion((0..<height).map { GridPoint(width - 1, $0) })
            set.formUnion((0..<width).map { GridPoint($0, height - 1) })
            points = Array(set)

        case .spiral:
            points = Self.buildSpiral(budget: budget, span: span)

        case .plusGrid:
            let height = clamp(max(3, Int(Double(budget + 4).squareRoot().rounded())), span)
            let width = clamp(max(3, (budget + 4 + height - 1) / height), span)
            var set = Set((0..<height).flatMap { y in (0..<width).map { GridPoint($0, y) } })
            set.remove(GridPoint(0, 0))
            set.remove(GridPoint(width - 1, 0))
            set.remove(GridPoint(0, height - 1))
            set.remove(GridPoint(width - 1, height - 1))
            points = Array(set)

        case .diamond:
            // A diamond of radius r holds 2r² + 2r + 1 cells; invert that so
            // the shape lands near its budget instead of far past it.
            let fromBudget = Int((((2 * Double(budget) - 1).squareRoot() - 1) / 2).rounded())
            let radius = max(1, min((span - 1) / 2, fromBudget))
            var set: Set<GridPoint> = []
            for dy in -radius...radius {
                let width = radius - abs(dy)
                for dx in -width...width { set.insert(GridPoint(dx + radius, dy + radius)) }
            }
            points = Array(set)
        }

        return ShapeArchetype.normalise(points)
    }

    private func clamp(_ value: Int, _ span: Int) -> Int { min(max(value, 3), span) }
    private func clamp2(_ value: Int, _ span: Int) -> Int { min(max(value, 2), span) }

    // MARK: - Builders that need more than one expression

    private static func buildStaircase(budget: Int, span: Int, rng: inout SplitMix64) -> [GridPoint] {
        var points = [GridPoint(0, 0)]
        var cursor = GridPoint(0, 0)
        var horizontal = rng.nextBool(probability: 0.5)
        var width = 1, height = 1

        while points.count < budget {
            let run = rng.nextInt(in: 3...max(3, min(span, 4)))
            let grows = run - 1
            if horizontal, width + grows > span { break }
            if !horizontal, height + grows > span { break }
            for _ in 0..<grows {
                cursor = horizontal ? cursor.offset(dx: 1, dy: 0) : cursor.offset(dx: 0, dy: 1)
                points.append(cursor)
            }
            if horizontal { width += grows } else { height += grows }
            horizontal.toggle()
        }
        return points
    }

    private static func buildFrame(width: Int, height: Int) -> [GridPoint] {
        var set: Set<GridPoint> = []
        for x in 0..<width {
            set.insert(GridPoint(x, 0))
            set.insert(GridPoint(x, height - 1))
        }
        for y in 0..<height {
            set.insert(GridPoint(0, y))
            set.insert(GridPoint(width - 1, y))
        }
        return Array(set)
    }

    /// A self-avoiding walk that never lets the path touch itself, so every
    /// arm of the spiral stays a run of its own.
    private static func buildSpiral(budget: Int, span: Int) -> [GridPoint] {
        let deltas = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        var occupied: Set<GridPoint> = [GridPoint(0, 0)]
        var path = [GridPoint(0, 0)]
        var cursor = GridPoint(0, 0)
        var direction = 0
        var turns = 0

        func isPlaceable(_ candidate: GridPoint, from previous: GridPoint) -> Bool {
            guard candidate.x >= 0, candidate.y >= 0, candidate.x < span, candidate.y < span else { return false }
            guard !occupied.contains(candidate) else { return false }
            for dy in -1...1 {
                for dx in -1...1 where !(dx == 0 && dy == 0) {
                    let neighbour = candidate.offset(dx: dx, dy: dy)
                    if neighbour != previous && occupied.contains(neighbour) { return false }
                }
            }
            return true
        }

        while path.count < budget && turns < 4 {
            let delta = deltas[direction]
            let candidate = cursor.offset(dx: delta.0, dy: delta.1)
            if isPlaceable(candidate, from: cursor) {
                occupied.insert(candidate)
                path.append(candidate)
                cursor = candidate
                turns = 0
            } else {
                direction = (direction + 1) % 4
                turns += 1
            }
        }
        return path
    }

    static func normalise(_ points: [GridPoint]) -> [GridPoint] {
        guard let bounds = GridBounds(points: points) else { return points }
        let shifted = points.map { GridPoint($0.x - bounds.minX, $0.y - bounds.minY) }
        return Array(Set(shifted)).sorted()
    }

    /// Rotates/mirrors a shape so repeated archetypes do not look identical.
    static func orient(_ points: [GridPoint], variant: Int) -> [GridPoint] {
        let transformed = points.map { point -> GridPoint in
            switch variant % 4 {
            case 1: GridPoint(-point.y, point.x)
            case 2: GridPoint(-point.x, -point.y)
            case 3: GridPoint(point.y, -point.x)
            default: point
            }
        }
        let mirrored = variant >= 4 ? transformed.map { GridPoint(-$0.x, $0.y) } : transformed
        return normalise(mirrored)
    }
}
