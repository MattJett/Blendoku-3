import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress

    private var nextLevel: Int { progress.furthestUnlocked }
    private var palette: [BlendColor] { DifficultyCurve.profile(for: nextLevel).previewRamp }
    private var started: Bool { progress.completedCount > 0 }

    var body: some View {
        GeometryReader { proxy in
            let strip = (proxy.size.width - EdgeRail.width) / CGFloat(BlendPreviewStrip.count)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Spacer(minLength: 0)
                    CircleIconButton(systemName: "slider.horizontal.3", label: "Settings") {
                        router.push(.settings)
                    }
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.top, Theme.Space.tight)
                .staggeredAppear(index: 0, perItem: 0.05)

                Spacer(minLength: Theme.Space.base)

                masthead
                    .padding(.horizontal, Theme.Space.margin)

                Spacer(minLength: Theme.Space.base)

                // Runs the full width of the device. The moment the game is
                // built around is a gap closing in a continuous blend, so it is
                // shown at the largest size the screen allows, with nothing
                // framing it.
                BlendPreviewStrip(palette: palette, side: strip)
                    .padding(.leading, EdgeRail.width)
                    .staggeredAppear(index: 3, perItem: 0.06, travel: 20)

                Spacer(minLength: Theme.Space.base)

                VStack(alignment: .leading, spacing: Theme.Space.base) {
                    progressBlock
                    actions
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.bottom, Theme.Space.snug)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .overlay(alignment: .leading) { EdgeRail(palette: palette) }
        }
        .onAppear { router.backdropPalette = palette }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            MoodLabel("One hundred blends")
                .staggeredAppear(index: 1, perItem: 0.06)

            EmbossedTitle(text: "Blendoku")
                .staggeredAppear(index: 1, perItem: 0.06)

            Text("Slide every tile until the colours blend evenly, end to end.")
                .font(Theme.text(15))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, Theme.Space.wide)
                .staggeredAppear(index: 2, perItem: 0.06)
        }
    }

    // MARK: - Progress

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .bottom, spacing: Theme.Space.wide) {
                Readout(value: "\(progress.completedCount)/\(DifficultyCurve.levelCount)",
                        label: "solved", size: 26)
                Readout(value: "\(progress.totalStars)", label: "stars", size: 26)
                Spacer(minLength: 0)
                Readout(value: String(format: "%03d", nextLevel), label: "up next",
                        size: 26, alignment: .trailing)
            }

            FillRule(fraction: Double(progress.completedCount)
                     / Double(DifficultyCurve.levelCount))
        }
        .staggeredAppear(index: 4, perItem: 0.06)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Theme.Space.snug) {
            Button {
                Haptics.play(.select)
                router.push(.game(nextLevel))
            } label: {
                Text(started ? "Continue · Level \(nextLevel)" : "Start playing")
            }
            .buttonStyle(PillButtonStyle(chip: Color(palette.last ?? palette[0])))
            .staggeredAppear(index: 5, perItem: 0.05)

            HStack(spacing: Theme.Space.snug) {
                Button("Levels") { router.push(.levels) }
                    .buttonStyle(OutlineButtonStyle())
                Button("How to play") { router.push(.howToPlay) }
                    .buttonStyle(OutlineButtonStyle())
            }
            .staggeredAppear(index: 6, perItem: 0.05)
        }
    }
}

// MARK: - Title

/// The wordmark, cut into the page rather than painted onto it.
///
/// Two offset shadows — one light above, one dark below — give the letterforms
/// a millimetre of relief. It is the moodboard's move for display type: depth
/// carries the hierarchy so hue does not have to, which leaves every saturated
/// pixel on this screen belonging to the puzzle.
@MainActor
struct EmbossedTitle: View {
    let text: String
    var size: CGFloat = 52

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(Theme.display(size, weight: .light))
            .kerning(-1.4)
            .foregroundStyle(Theme.textPrimary)
            .shadow(color: .white.opacity(scheme == .dark ? 0.10 : 0.85), radius: 0.5, x: 0, y: -1)
            .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.16), radius: 1.5, x: 0, y: 2)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Edge rail

/// A four-point band of the next level's colour, flush to the left edge and
/// running the whole height of the screen. It is the only piece of chrome that
/// changes as you progress, and it is small enough to read as a bookmark.
@MainActor
struct EdgeRail: View {
    let palette: [BlendColor]

    static let width: CGFloat = 4

    var body: some View {
        LinearGradient(colors: palette.map { Color($0) },
                       startPoint: .top, endPoint: .bottom)
            .frame(width: Self.width)
            .overlay(Striation(spacing: 2, opacity: 0.10))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Preview strip

/// Six tiles that keep taking one out and dropping it back.
///
/// They sit flush, exactly as they do on the board, and now run the full width
/// of the device with square ends, so the strip reads as a band of colour the
/// screen has been cut out of rather than as a widget sitting on it.
@MainActor
struct BlendPreviewStrip: View {
    let palette: [BlendColor]
    let side: CGFloat

    @State private var liftedIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let count = 6
    private var count: Int { Self.count }

    private var colours: [BlendColor] {
        guard let first = palette.first, let last = palette.last else { return [] }
        return (0..<count).map { BlendColor.mix(first, last, Double($0) / Double(count - 1)) }
    }

    /// Headroom above the row for the tile that lifts out.
    private var lift: CGFloat { side * 0.46 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(Array(colours.enumerated()), id: \.offset) { index, colour in
                    cell(index: index, colour: colour)
                }
            }
            .frame(height: side)
        }
        .frame(height: side + lift + 10)
        .onAppear { start() }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cell(index: Int, colour: BlendColor) -> some View {
        let lifted = liftedIndex == index

        ZStack {
            // Only visible once the tile above it has moved out of the way.
            SlotView(size: side, isHovered: false, isHinted: false)
                .opacity(lifted ? 1 : 0)

            TileView(colour: colour, size: side, role: .placed, corners: [], bleed: 0.5)
                .offset(y: lifted ? -lift : 0)
                .shadow(color: .black.opacity(lifted ? 0.34 : 0),
                        radius: lifted ? 16 : 0, y: lifted ? 10 : 0)
        }
        .frame(width: side, height: side)
        .zIndex(lifted ? 1 : 0)
    }

    private func start() {
        guard !reduceMotion else { return }
        Task { await cycle() }
    }

    private func cycle() async {
        var step = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1700))
            // Never the end tiles — a hole in the middle reads as a gap in the
            // blend, which is the thing worth showing.
            withAnimation(Motion.settle) {
                liftedIndex = 1 + step % (count - 2)
            }
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(Motion.tile) { liftedIndex = nil }
            step += 1
        }
    }
}
