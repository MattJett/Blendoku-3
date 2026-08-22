import Foundation

/// A hundred levels that belong together.
///
/// The difficulty curve is a function of one number, `t`, running 0 to 1. An
/// arc is a *window onto that curve*: Chromarc 1 takes the whole of it, and a
/// later arc starts partway along, so its first level lands where the previous
/// arc's middle did rather than back at three cells.
///
/// Only the window and the seed differ. Everything that makes a board — the
/// gamut solving, the uniqueness proof, the shape vocabulary — is shared, so a
/// new arc cannot drift away from the game the first one taught.
struct Chromarc: Identifiable, Hashable, Sendable {
    let number: Int
    let title: String
    /// Where this arc sits on the shared difficulty curve.
    let span: ClosedRange<Double>
    /// Arcs beyond the first are declared before they are built, so the chooser
    /// can show what is coming without pretending it is playable.
    let isPlayable: Bool

    var id: Int { number }

    /// The `t` a level maps to inside this arc.
    func progress(at level: Int) -> Double {
        let clamped = min(max(level, 1), DifficultyCurve.levelCount)
        let local = Double(clamped - 1) / Double(DifficultyCurve.levelCount - 1)
        return span.lowerBound + (span.upperBound - span.lowerBound) * local
    }

    /// The arc's palette as one continuous sweep.
    ///
    /// Not a concatenation of per-level ramps, which is what this was first
    /// built as and why it came out looking like a barcode: a hundred levels
    /// are a hundred *different* palettes, spaced a golden angle apart, and
    /// stringing them together gives thirty-odd colours with a hue jump between
    /// every pair. No ordering fixes that, because the jumps are the content.
    ///
    /// What the arc actually covers is the whole hue wheel, climbing in
    /// lightness as the boards get subtler. So the ribbon is built as exactly
    /// that — one diagonal through the colour solid — and comes out smooth
    /// because it is smooth, rather than because it has been sorted.
    func previewRamp(steps: Int = 48) -> [BlendColor] {
        let mid = DifficultyCurve.profile(for: DifficultyCurve.levelCount / 2, arc: number)
        return (0..<steps).map { index in
            let t = Double(index) / Double(max(1, steps - 1))
            return BlendColor(lightness: 0.30 + 0.42 * t,
                              chroma: min(0.115 * mid.chromaFraction.upperBound,
                                          mid.maxCellChroma),
                              hue: t * 360)
                .clippedToGamut()
        }
    }

    static let first = Chromarc(
        number: 1,
        title: "First Light",
        span: 0...1,
        isPlayable: true)

    /// Declared, not built.
    ///
    /// The span starts a third of the way along so it opens at something like
    /// Chromarc 1's level 35 rather than at three cells. It *ends* at the same
    /// place, and that is the honest state of it: "slightly harder than the
    /// first arc's ending" cannot come from extending this window, because the
    /// end of the window is already the point where `minStep` sits on the floor
    /// the sRGB gamut imposes. Making arc 2 finish harder means leaning on the
    /// levers that are not gamut-bound — more decoys, more independent shapes,
    /// less forgiving stars — and that is work for when this arc is built, not
    /// a constant to raise here.
    static let second = Chromarc(
        number: 2,
        title: "Second Light",
        span: 0.35...1,
        isPlayable: false)

    static let all: [Chromarc] = [.first, .second]

    static func numbered(_ number: Int) -> Chromarc {
        all.first { $0.number == number } ?? .first
    }
}
