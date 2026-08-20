import SwiftUI

/// What you get for solving one.
///
/// A single sculpted panel: no border, no glass, no tint — the ground colour of
/// whichever theme is running, made three-dimensional by nothing but a dark
/// shadow falling one way and a light one falling the other. All white on
/// paper, all black on ink.
///
/// Everything inside obeys the same rule. The stars are three bumps, and an
/// unearned one is the same bump pressed *into* the panel rather than a dimmed
/// copy of it. The palette is inlaid in a trough. That palette is the only
/// colour in the frame, which is the point: it is the thing the player just
/// built, and the monochrome around it is what lets it land.
@MainActor
struct VictoryOverlay: View {
    let puzzle: Puzzle
    let record: LevelRecord
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    @State private var appeared = false

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
            // Nearly opaque, unlike the old glass. A sculpted surface only
            // reads as sculpted when the thing behind it is the same colour —
            // over a half-seen board it would look like a card lying on top of
            // one instead of a shape pressed out of the page.
            Theme.ground.opacity(appeared ? 0.94 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            SoftPanel(radius: Theme.Radius.panel, padding: Theme.Space.wide, depth: 22) {
                VStack(spacing: Theme.Space.base) {
                    VStack(spacing: 6) {
                        MoodLabel("Level \(puzzle.level) solved")
                        Text("Blended")
                            .font(Theme.display(40))
                            .kerning(-0.8)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    SoftPips(filled: record.stars, total: 3)

                    // The palette they just rebuilt, inlaid in the panel.
                    SwatchBar(colours: swatches, height: 34, radius: 9)
                        .padding(5)
                        .softSurface(RoundedRectangle(cornerRadius: 15, style: .continuous),
                                     depth: 7, pressed: true)

                    HStack(spacing: Theme.Space.base) {
                        Readout(value: "\(record.moves)", label: "moves", size: 17, alignment: .center)
                        Readout(value: timeText, label: "time", size: 17, alignment: .center)
                        Readout(value: "\(puzzle.slots.count)", label: "tiles", size: 17, alignment: .center)
                    }

                    VStack(spacing: Theme.Space.snug) {
                        if hasNextLevel {
                            Button("Next level") { onNext() }
                                .buttonStyle(PillButtonStyle())
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
        }
    }

    private var timeText: String {
        let seconds = Int(record.seconds.rounded())
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
}

/// A score shown as relief rather than as colour: an earned mark stands out of
/// the panel, an unearned one is pressed into it. Reading it is the same act as
/// reading the rest of the screen, which is what keeps the window monochrome
/// without making it flat.
@MainActor
private struct SoftPips: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            ForEach(0..<total, id: \.self) { index in
                SoftSurface(shape: Circle(),
                            depth: index < filled ? 7 : 5,
                            pressed: index >= filled)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total) stars")
    }
}
