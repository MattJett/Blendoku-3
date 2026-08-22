import SwiftUI
import UIKit

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
    /// The last board of the arc, with every other one behind it. The primary
    /// action stops being "next" and becomes the end of the hundred.
    let arcComplete: Bool
    let onNext: () -> Void
    let onFinishArc: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    @Environment(BlendLibrary.self) private var library

    @State private var appeared = false
    @State private var copied = false

    /// `paletteSwatches` hands back what it has, which for a degenerate puzzle
    /// could be a single colour. Everything below indexes into this, so pad it.
    private var swatches: [BlendColor] {
        // More samples than the old seven: the ribbon is continuous now, so
        // every extra sample is a real bend in the curve rather than another
        // block in a row.
        let drawn = puzzle.paletteSwatches(count: 14)
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
                            .font(Theme.display(42))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    SoftPips(filled: record.stars, total: 3)

                    // The palette they just rebuilt, inlaid in the panel — and
                    // now as one continuous ribbon rather than a row of blocks.
                    // The cell boundaries were the puzzle; once it is solved
                    // they are the only thing standing between the player and
                    // the blend they made.
                    VStack(spacing: Theme.Space.tight) {
                        GradientRibbon(colours: swatches)
                            .padding(6)
                            .softSurface(RoundedRectangle(cornerRadius: 20, style: .continuous),
                                         depth: 8, pressed: true)

                        HStack(spacing: Theme.Space.snug) {
                            Button {
                                UIPasteboard.general.string = GradientRibbon.css(swatches)
                                Haptics.play(.snap)
                                withAnimation(Motion.quick) { copied = true }
                            } label: {
                                Label(copied ? "Copied" : "Copy CSS",
                                      systemImage: copied ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(OutlineButtonStyle())
                            .accessibilityHint("Copies this blend as a CSS linear-gradient")

                            Button {
                                library.keep(level: puzzle.level, arc: puzzle.arc,
                                             colours: swatches)
                                Haptics.play(.snap)
                            } label: {
                                Label(isKept ? "Kept" : "Keep",
                                      systemImage: isKept ? "bookmark.fill" : "bookmark")
                            }
                            .buttonStyle(OutlineButtonStyle())
                            .accessibilityHint("Saves this blend to your collection")
                        }
                    }

                    HStack(spacing: Theme.Space.base) {
                        Readout(value: "\(record.moves)", label: "moves", size: 17, alignment: .center)
                        Readout(value: timeText, label: "time", size: 17, alignment: .center)
                        Readout(value: "\(puzzle.slots.count)", label: "tiles", size: 17, alignment: .center)
                    }

                    VStack(spacing: Theme.Space.snug) {
                        if hasNextLevel {
                            Button("Next level") { onNext() }
                                .buttonStyle(PillButtonStyle())
                        } else if arcComplete {
                            Button("Finish the arc") { onFinishArc() }
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

    /// Keeping the same level twice replaces rather than duplicates, so the
    /// button only ever needs to say whether this board is already on the shelf.
    private var isKept: Bool { library.saved(arc: puzzle.arc, level: puzzle.level) != nil }

    private var timeText: String {
        let seconds = Int(record.seconds.rounded())
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
}

/// A score shown as relief rather than as colour: an earned mark stands out of
/// the panel, an unearned one is pressed into it. Reading it is the same act as
/// reading the rest of the screen, which is what keeps the window monochrome
/// without making it flat.
///
/// The two states differ in size as well as in lighting. Shading alone is not
/// enough at this scale — a bump and a dent sixteen points across look much the
/// same at a glance, and a score you have to squint at is not a score. The size
/// step is what makes the count readable; the lighting is what makes it belong.
@MainActor
private struct SoftPips: View {
    let filled: Int
    let total: Int

    private let cell: CGFloat = 20

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            ForEach(0..<total, id: \.self) { index in
                let earned = index < filled
                SoftSurface(shape: Circle(),
                            depth: earned ? 8 : 5,
                            pressed: !earned)
                    .frame(width: earned ? cell : cell * 0.6,
                           height: earned ? cell : cell * 0.6)
                    .frame(width: cell, height: cell)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        // The marks sit in a recessed track. On ink the highlight that makes a
        // bump a bump is only a few points brighter than the panel, which is
        // plenty across a button and nothing at all across a twenty-point
        // circle; dropping the whole row into a trough gives the bumps a darker
        // field to stand out of, and costs no colour to do it.
        .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous),
                     depth: 7, pressed: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total) stars")
    }
}
