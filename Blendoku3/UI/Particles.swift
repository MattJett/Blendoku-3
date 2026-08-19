import SwiftUI

/// A one-shot burst of confetti in the level's own colours, drawn in a Canvas
/// so a few hundred pieces cost nothing.
@MainActor
struct ConfettiBurst: View {
    var palette: [BlendColor]
    var seed: UInt64
    var pieceCount = 90

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private struct Piece {
        var origin: CGPoint
        var velocity: CGVector
        var spin: Double
        var phase: Double
        var size: CGFloat
        var colour: Color
    }

    var body: some View {
        let pieces = Self.build(count: pieceCount, palette: palette, seed: seed)

        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince(start)
                guard time < 3.2 else { return }
                for piece in pieces {
                    let x = piece.origin.x * size.width + piece.velocity.dx * time
                    let y = piece.origin.y * size.height + piece.velocity.dy * time + 240 * time * time
                    guard y < size.height + 40 else { continue }
                    let fade = max(0, 1 - time / 3.0)
                    let wobble = cos(time * piece.spin + piece.phase)
                    let rect = CGRect(x: x, y: y,
                                      width: piece.size * (0.35 + 0.65 * abs(wobble)),
                                      height: piece.size)
                    var layer = context
                    layer.opacity = fade
                    layer.fill(Path(roundedRect: rect, cornerRadius: piece.size * 0.28),
                               with: .color(piece.colour))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func build(count: Int, palette: [BlendColor], seed: UInt64) -> [Piece] {
        var rng = SplitMix64(seed: seed)
        let colours = palette.isEmpty ? [BlendColor(lightness: 0.7, chroma: 0.12, hue: 220)] : palette
        return (0..<count).map { _ in
            let angle = rng.nextDouble(in: (-Double.pi * 0.92)...(-Double.pi * 0.08))
            let speed = rng.nextDouble(in: 190...460)
            return Piece(origin: CGPoint(x: rng.nextDouble(in: 0.2...0.8),
                                         y: rng.nextDouble(in: 0.42...0.58)),
                         velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                         spin: rng.nextDouble(in: 3...9),
                         phase: rng.nextDouble(in: 0...(2 * Double.pi)),
                         size: rng.nextDouble(in: 5...11),
                         colour: Color(rng.pick(colours)))
        }
    }
}
