import Foundation

/// Everything about a level that is decided before any randomness is drawn.
/// Keeping it in one value makes the difficulty ramp readable — and testable.
struct DifficultyProfile: Sendable {
    let level: Int
    let chapter: Chapter
    /// How many cells the board should end up with.
    let targetCells: Int
    /// How many of those cells the player has to fill.
    let targetSlots: Int
    /// How many independent shapes share the tray.
    let componentCount: Int
    /// Shapes this level is allowed to draw from.
    let archetypes: [ShapeArchetype]
    /// Smallest perceptual distance between neighbouring tiles. This is the
    /// main difficulty dial: big steps are obvious, small steps are agony.
    let minStep: Double
    let maxStep: Double
    /// Tray tiles that fit nowhere.
    let decoyCount: Int
    /// Centre hue of the level's palette, unique to this level.
    let baseHue: Double
    /// How far the palette is allowed to travel around the hue wheel.
    let hueSpread: Double
    /// How much of the colour the display can actually show at these
    /// lightnesses to use, 0 (grey) ... 1 (as vivid as sRGB allows).
    let chromaFraction: ClosedRange<Double>
    /// Hard ceiling on any single tile's chroma, which is what keeps the
    /// quiet chapters quiet.
    let maxCellChroma: Double
    let lightnessRange: ClosedRange<Double>
    /// Longest a single straight line may be.
    let maxSpan: Int
    /// Longest side of a shape that blends in both directions. Shorter than
    /// `maxSpan`, because a two-way blend has to spend its colour budget
    /// twice and sRGB simply does not hold that much.
    let maxSpan2D: Int

    /// A cheap sample of the level's palette for the level-select grid. Built
    /// straight from the profile so the grid never has to generate 100 puzzles.
    var previewRamp: [BlendColor] {
        let steps = 4
        let chroma = 0.16 * chromaFraction.upperBound
        return (0..<steps).map { index in
            let t = Double(index) / Double(steps - 1)
            let lightness = 0.34 + 0.40 * t
            let hue = baseHue + hueSpread * (t - 0.5) * 0.5
            return BlendColor(lightness: lightness,
                              chroma: min(chroma, maxCellChroma),
                              hue: hue).clippedToGamut()
        }
    }

    /// 0...1, shown to the player as a row of pips.
    var difficultyScore: Double {
        let size = Double(targetSlots - 2) / 14
        let subtlety = (0.210 - minStep) / 0.152
        let clutter = Double(decoyCount) / 4
        let spread = Double(componentCount - 1) / 3
        let raw = size * 0.34 + subtlety * 0.40 + clutter * 0.13 + spread * 0.13
        return min(1, max(0, raw))
    }
}

enum DifficultyCurve {
    static let levelCount = 100

    static func profile(for level: Int) -> DifficultyProfile {
        let level = min(max(level, 1), levelCount)
        let chapter = Chapter.containing(level: level)
        let t = Double(level - 1) / Double(levelCount - 1)

        // Boards stay small while the steps are still coarse — a long line
        // needs more colour space than a coarse step leaves — and grow once
        // the palette has tightened enough to afford the length.
        let cells = 3 + Int((23 * pow(t, 1.6)).rounded())
        let slotRatio = 0.56 + 0.22 * t
        let slots = min(14, max(2, Int((Double(cells) * slotRatio).rounded())))

        let minStep = 0.058 + 0.152 * pow(1 - t, 1.9)
        let maxStep = minStep * (1.75 - 0.45 * t)

        let decoys: Int
        switch level {
        case ...25: decoys = 0
        case ...45: decoys = 1
        case ...65: decoys = 2
        case ...85: decoys = 3
        default: decoys = 4
        }

        let components = componentCount(for: level, cells: cells)

        // The golden angle keeps consecutive levels far apart on the hue wheel
        // while still visiting every hue across the hundred.
        let baseHue = (Double(level) * 137.50776405003785).truncatingRemainder(dividingBy: 360)

        // A run of n tiles has to travel (n-1) steps through colour space, and
        // there is only so much of it. Long lines therefore arrive only once
        // the steps have become small.
        let maxSpan = min(9, max(3, min(3 + Int((6 * t).rounded()), Int(0.72 / minStep) + 1)))

        return DifficultyProfile(
            level: level,
            chapter: chapter,
            targetCells: cells,
            targetSlots: slots,
            componentCount: components,
            archetypes: archetypes(for: chapter),
            minStep: minStep,
            maxStep: maxStep,
            decoyCount: decoys,
            baseHue: baseHue,
            hueSpread: 22 + 96 * pow(t, 0.7),
            chromaFraction: chromaFraction(for: chapter),
            maxCellChroma: maxCellChroma(for: chapter),
            lightnessRange: lightnessRange(for: chapter),
            maxSpan: maxSpan,
            maxSpan2D: max(3, min(maxSpan, Int(0.34 / minStep) + 1))
        )
    }

    private static func componentCount(for level: Int, cells: Int) -> Int {
        let wanted: Int
        switch level {
        case ...36: wanted = 1
        case ...52: wanted = level % 4 == 0 ? 1 : 2
        case ...70: wanted = level % 5 == 0 ? 3 : 2
        case ...86: wanted = level % 3 == 0 ? 2 : 3
        default: wanted = level % 2 == 0 ? 3 : 4
        }
        return max(1, min(wanted, cells / 3))
    }

    private static func archetypes(for chapter: Chapter) -> [ShapeArchetype] {
        switch chapter {
        case .firstLight: [.row, .column]
        case .turningPoint: [.row, .column, .elbow, .tee]
        case .crossroads: [.elbow, .tee, .cross, .staircase]
        case .lattice: [.block, .plusGrid, .cross, .tee]
        case .twinThreads: [.row, .elbow, .block, .tee, .cross]
        case .deepField: [.block, .comb, .ladder, .tee, .cross]
        case .whisper: [.block, .cross, .staircase, .hbar, .comb]
        case .constellation: [.row, .elbow, .block, .tee, .plusGrid, .diamond]
        case .labyrinth: [.frame, .ladder, .spiral, .ubar, .hbar, .comb]
        case .eventHorizon: [.block, .frame, .spiral, .diamond, .ladder, .cross, .staircase]
        }
    }

    private static func chromaFraction(for chapter: Chapter) -> ClosedRange<Double> {
        switch chapter {
        case .firstLight: 0.60...1.00
        case .turningPoint: 0.58...1.00
        case .crossroads: 0.50...0.95
        case .lattice: 0.48...0.92
        case .twinThreads: 0.44...0.90
        case .deepField: 0.40...0.88
        case .whisper: 0.08...0.30
        case .constellation: 0.38...0.85
        case .labyrinth: 0.30...0.72
        case .eventHorizon: 0.24...0.85
        }
    }

    private static func maxCellChroma(for chapter: Chapter) -> Double {
        switch chapter {
        case .whisper: 0.130
        case .labyrinth: 0.28
        case .eventHorizon: 0.30
        default: 0.32
        }
    }

    private static func lightnessRange(for chapter: Chapter) -> ClosedRange<Double> {
        switch chapter {
        case .whisper: 0.34...0.80
        case .eventHorizon: 0.30...0.84
        default: 0.28...0.86
        }
    }
}
