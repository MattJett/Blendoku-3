import SwiftUI
import UIKit

/// What you get for solving one.
///
/// The whole screen becomes the page again — no panel floating over the
/// board, because a panel is not something you can press and so, by the rule
/// everything here follows, it has no business standing up. What stands up are
/// the controls. What is cut into the page is everything else: the word, the
/// stars that were not earned, the well the finished blend is inlaid in.
///
/// That blend is the only colour in the frame. It is the thing the player just
/// built, and the monochrome around it is what lets it land.
@MainActor
struct VictoryOverlay: View {
    let puzzle: Puzzle
    let record: LevelRecord
    let song: SongSchedule
    let warmth: Double
    let hasNextLevel: Bool
    /// The last board of the arc, with every other one behind it. The primary
    /// action stops being "next" and becomes the end of the hundred.
    let arcComplete: Bool
    let onNext: () -> Void
    let onFinishArc: () -> Void
    let onRetry: () -> Void
    let onArcs: () -> Void
    let onLevels: () -> Void

    @Environment(BlendLibrary.self) private var library

    @State private var appeared = false
    @State private var copied = false
    /// This board's song, as far as the performer is concerned.
    @State private var songID = UUID()

    private var performer: SongPerformer { .shared }

    /// `paletteSwatches` hands back what it has, which for a degenerate puzzle
    /// could be a single colour. Everything below indexes into this, so pad it.
    private var swatches: [BlendColor] {
        let drawn = puzzle.paletteSwatches(count: 14)
        guard let first = drawn.first else {
            return Array(repeating: BlendColor(lightness: 0.6, chroma: 0.08, hue: 40), count: 7)
        }
        return drawn.count >= 2 ? drawn : Array(repeating: first, count: 7)
    }

    private var isKept: Bool { library.saved(arc: puzzle.arc, level: puzzle.level) != nil }

    var body: some View {
        ZStack {
            Theme.ground.opacity(appeared ? 0.97 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            // Centred when it fits, scrolling when it does not — a small
            // phone at a large text size still reaches Next.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Space.base) {
                        header
                        SoftPips(filled: record.stars, total: 3)
                        ribbon
                        readouts
                        secondary
                        primary
                    }
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.vertical, Theme.Space.wide)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .scaleEffect(appeared ? 1 : 0.97)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) { appeared = true }
        }
        .onDisappear {
            if performer.playing == songID { performer.stop() }
        }
    }

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 6) {
            MonoLabel("Level \(String(format: "%03d", puzzle.level)) · \(Chromarc.numbered(puzzle.arc).title)")
            Text("Solved")
                .font(Theme.display(64))
                .textCase(.uppercase)
                .tracking(0.6)
                .carved()
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// The blend they rebuilt, inlaid, as one continuous ribbon — the cell
    /// boundaries were the puzzle, and once it is solved they are the only
    /// thing standing between the player and what they made.
    private var ribbon: some View {
        GradientRibbon(colours: swatches, height: 88, radius: 13)
            .overlay {
                if performer.playing == songID, let schedule = performer.schedule,
                   let startedAt = performer.startedAt {
                    SongPlayhead(schedule: schedule, startedAt: startedAt)
                }
            }
            .padding(6)
            .softSurface(RoundedRectangle(cornerRadius: 19, style: .continuous),
                         depth: 8, pressed: true)
    }

    private var readouts: some View {
        HStack(spacing: Theme.Space.base) {
            Readout(value: "\(record.moves)", label: "moves", size: 17, alignment: .center)
            Readout(value: timeText, label: "time", size: 17, alignment: .center)
            Readout(value: "\(puzzle.slots.count)", label: "tiles", size: 17, alignment: .center)
            Readout(value: String(format: "%.1fs", song.lastOnset), label: "song", size: 17,
                    alignment: .center)
        }
    }

    private var secondary: some View {
        HStack(spacing: Theme.Space.snug) {
            Button(action: onRetry) {
                SlabLabel(title: "Retry", size: 14)
            }
            .buttonStyle(SlabButtonStyle(depth: 6))
            .accessibilityIdentifier("victory.retry")

            Button {
                listen()
            } label: {
                SlabLabel(title: performer.playing == songID ? "Stop" : "Listen", size: 14)
            }
            .buttonStyle(SlabButtonStyle(depth: 6, isOn: performer.playing == songID))
            .accessibilityIdentifier("victory.listen")
            .accessibilityHint("Plays the song this board made")

            Button {
                UIPasteboard.general.string = GradientRibbon.css(swatches)
                Haptics.play(.snap)
                withAnimation(Motion.quick) { copied = true }
            } label: {
                SlabLabel(title: copied ? "Copied" : "CSS", size: 14)
            }
            .buttonStyle(SlabButtonStyle(depth: 6))
            .accessibilityIdentifier("victory.css")
            .accessibilityHint("Copies this blend as a CSS linear-gradient")
        }
    }

    private var primary: some View {
        HStack(spacing: Theme.Space.snug) {
            Button(action: onArcs) {
                SlabLabel(title: "Arcs", size: 20)
            }
            .buttonStyle(SlabButtonStyle(depth: 11))
            .accessibilityIdentifier("victory.arcs")

            Button(action: toggleKeep) {
                SlabLabel(title: isKept ? "Kept" : "Keep", tint: Theme.accent, size: 20)
            }
            .buttonStyle(SlabButtonStyle(depth: 11, isOn: isKept))
            .accessibilityIdentifier("victory.keep")
            .accessibilityHint(isKept ? "Removes it from your keepsakes"
                                      : "Saves the blend and its song to your keepsakes")

            if hasNextLevel {
                Button(action: onNext) {
                    SlabLabel(title: "Next →", size: 20)
                }
                .buttonStyle(SlabButtonStyle(depth: 11))
                .accessibilityIdentifier("victory.next")
                .accessibilityLabel("Next level")
            } else if arcComplete {
                Button(action: onFinishArc) {
                    SlabLabel(title: "Finish", size: 20)
                }
                .buttonStyle(SlabButtonStyle(depth: 11))
                .accessibilityIdentifier("victory.finish")
            } else {
                Button(action: onLevels) {
                    SlabLabel(title: "Levels", size: 20)
                }
                .buttonStyle(SlabButtonStyle(depth: 11))
                .accessibilityIdentifier("victory.levels")
            }
        }
        .padding(.top, Theme.Space.hair)
    }

    // MARK: - Actions

    private func listen() {
        if performer.playing == songID {
            performer.stop()
            return
        }
        Haptics.play(.select)
        Task { await performer.perform(song, warmth: warmth, id: songID) }
    }

    /// Keep is a latch: pressing it again lets the keepsake go.
    private func toggleKeep() {
        Haptics.play(.snap)
        if let kept = library.saved(arc: puzzle.arc, level: puzzle.level) {
            library.remove(kept)
        } else {
            library.keep(level: puzzle.level, arc: puzzle.arc, colours: swatches,
                         melody: song.melody.map(\.colour),
                         spectrum: song.climb.map(\.colour),
                         warmth: warmth)
        }
    }

    private var timeText: String {
        let seconds = Int(record.seconds.rounded())
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
}

/// The score, inlaid. An earned star is a block of the accent set into the
/// track; an unearned one is an empty socket pressed into it. Nothing stands
/// up — a score is not something to press.
///
/// The two states differ in size as well as in colour. At this scale a full
/// socket and an empty one need more than one difference to be told apart at
/// a glance, and a score you have to squint at is not a score.
@MainActor
struct SoftPips: View {
    let filled: Int
    let total: Int

    private let cell: CGFloat = 20

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            ForEach(0..<total, id: \.self) { index in
                pip(earned: index < filled)
                    .frame(width: cell, height: cell)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous),
                     depth: 7, pressed: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total) stars")
    }

    @ViewBuilder
    private func pip(earned: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        if earned {
            shape.fill(Theme.accent)
                .frame(width: cell, height: cell)
        } else {
            SoftSurface(shape: shape, depth: 4, pressed: true)
                .frame(width: cell * 0.6, height: cell * 0.6)
        }
    }
}
