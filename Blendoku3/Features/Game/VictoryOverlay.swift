import SwiftUI

/// What you get for solving one.
///
/// A single sheet of glass over the finished board, with the solved palette
/// blooming behind it. Confetti used to live here; it was the one moment in the
/// app throwing colour around at random, which is exactly the judgement the
/// rest of the game asks the player to make carefully. The board's own solve
/// ripple already carries the celebration, in the colours they earned.
@MainActor
struct VictoryOverlay: View {
    let puzzle: Puzzle
    let record: LevelRecord
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    @State private var appeared = false
    @State private var bloomed = false

    /// `paletteSwatches` hands back what it has, which for a degenerate puzzle
    /// could be a single colour. Everything below indexes into this, so pad it.
    private var swatches: [BlendColor] {
        let drawn = puzzle.paletteSwatches(count: 7)
        guard let first = drawn.first else {
            return Array(repeating: BlendColor(lightness: 0.6, chroma: 0.08, hue: 40), count: 7)
        }
        return drawn.count >= 2 ? drawn : Array(repeating: first, count: 7)
    }

    var body: some View {
        ZStack {
            Theme.ground.opacity(appeared ? 0.62 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                PigmentOrb(colour: swatches[swatches.count / 2],
                           diameter: max(proxy.size.width, proxy.size.height) * 1.1,
                           intensity: 0.5)
                    .scaleEffect(bloomed ? 1 : 0.35)
                    .opacity(bloomed ? 1 : 0)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.42)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GlassPanel(radius: Theme.Radius.panel, padding: Theme.Space.wide) {
                VStack(spacing: Theme.Space.base) {
                    VStack(spacing: 6) {
                        MoodLabel("Level \(puzzle.level) solved")
                        Text("Blended")
                            .font(Theme.display(40))
                            .kerning(-0.8)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    DotRow(count: record.stars, tint: Theme.accent, size: 9,
                           spokenLabel: "\(record.stars) of 3 stars")

                    // The palette they just rebuilt, shown as the one bar it
                    // always wanted to be.
                    SwatchBar(colours: swatches, height: 34, radius: 10)

                    HStack(spacing: Theme.Space.base) {
                        Readout(value: "\(record.moves)", label: "moves", size: 17, alignment: .center)
                        Readout(value: timeText, label: "time", size: 17, alignment: .center)
                        Readout(value: "\(puzzle.slots.count)", label: "tiles", size: 17, alignment: .center)
                    }

                    VStack(spacing: Theme.Space.snug) {
                        if hasNextLevel {
                            Button("Next level") { onNext() }
                                .buttonStyle(PillButtonStyle(chip: Color(swatches[swatches.count - 1])))
                        }
                        HStack(spacing: Theme.Space.snug) {
                            Button("Replay") { onReplay() }
                                .buttonStyle(OutlineButtonStyle())
                            Button("Levels") { onLevels() }
                                .buttonStyle(OutlineButtonStyle())
                        }
                    }
                    .padding(.top, Theme.Space.hair)
                }
            }
            .padding(.horizontal, Theme.Space.margin)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) { appeared = true }
            withAnimation(.easeOut(duration: 1.4)) { bloomed = true }
        }
    }

    private var timeText: String {
        let seconds = Int(record.seconds.rounded())
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
}
