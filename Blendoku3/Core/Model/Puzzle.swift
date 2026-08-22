import Foundation

/// One tile the player can move. Ids are stable for the lifetime of a puzzle
/// so SwiftUI can animate a tile from the tray to the board and back.
struct Tile: Identifiable, Hashable, Sendable {
    let id: Int
    let color: BlendColor
    /// Decoys belong to no slot — they exist only to be ruled out.
    let isDecoy: Bool
}

/// A maximal straight line of three or more cells. Every run must read as an
/// even blend from one end to the other.
struct PuzzleRun: Hashable, Sendable {
    enum Axis: Sendable { case horizontal, vertical }
    let axis: Axis
    let points: [GridPoint]
}

/// A fully generated level: the shape of the board, which cells are given,
/// and the tiles that have to be placed into the rest.
struct Puzzle: Identifiable, Sendable {
    let level: Int
    /// Which Chromarc this board belongs to. Carried on the puzzle rather than
    /// passed alongside it, so anything holding a board — the victory panel
    /// saving a blend, a record being written — knows where it came from
    /// without the caller having to remember.
    var arc: Int = 1
    let seed: UInt64
    let chapter: Chapter
    /// Every occupied cell, in reading order.
    let cells: [GridPoint]
    /// The intended colour of every cell.
    let solution: [GridPoint: BlendColor]
    /// Cells that start on the board and cannot be moved.
    let clues: Set<GridPoint>
    /// Cells the player has to fill, in reading order.
    let slots: [GridPoint]
    /// All maximal runs of length >= 3.
    let runs: [PuzzleRun]
    /// Tray contents: one tile per slot plus any decoys, pre-shuffled.
    let tiles: [Tile]
    let bounds: GridBounds

    var id: Int { arc * 1000 + level }
    var columns: Int { bounds.width }
    var rows: Int { bounds.height }
    var decoyCount: Int { tiles.filter(\.isDecoy).count }

    /// The tile that belongs in `point`, or nil for clue cells.
    func solutionTile(for point: GridPoint) -> Tile? {
        guard let color = solution[point], !clues.contains(point) else { return nil }
        return tiles.first { !$0.isDecoy && $0.color == color }
    }

    /// A representative sample of the palette, used for level-select artwork.
    func paletteSwatches(count: Int = 5) -> [BlendColor] {
        let ordered = cells.compactMap { solution[$0] }
        guard ordered.count > 1 else { return ordered }
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let position = Int((t * Double(ordered.count - 1)).rounded())
            return ordered[position]
        }
    }
}

/// Ten themed chapters of ten levels each.
enum Chapter: Int, CaseIterable, Sendable, Identifiable {
    case firstLight = 1
    case turningPoint
    case crossroads
    case lattice
    case twinThreads
    case deepField
    case whisper
    case constellation
    case labyrinth
    case eventHorizon

    var id: Int { rawValue }

    static func containing(level: Int) -> Chapter {
        let index = max(1, min(10, (level - 1) / 10 + 1))
        return Chapter(rawValue: index) ?? .firstLight
    }

    var title: String {
        switch self {
        case .firstLight: "First Light"
        case .turningPoint: "Turning Point"
        case .crossroads: "Crossroads"
        case .lattice: "Lattice"
        case .twinThreads: "Twin Threads"
        case .deepField: "Deep Field"
        case .whisper: "Whisper"
        case .constellation: "Constellation"
        case .labyrinth: "Labyrinth"
        case .eventHorizon: "Event Horizon"
        }
    }

    var subtitle: String {
        switch self {
        case .firstLight: "Single strands of colour"
        case .turningPoint: "Corners and branches"
        case .crossroads: "Lines that meet"
        case .lattice: "Blends in two directions"
        case .twinThreads: "Two puzzles, one tray"
        case .deepField: "Bigger fields, false tiles"
        case .whisper: "Barely there differences"
        case .constellation: "Scattered fragments"
        case .labyrinth: "Frames, ladders, spirals"
        case .eventHorizon: "Everything at once"
        }
    }

    var levels: ClosedRange<Int> { ((rawValue - 1) * 10 + 1)...(rawValue * 10) }
}
