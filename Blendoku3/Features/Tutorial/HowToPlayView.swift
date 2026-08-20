import SwiftUI

@MainActor
struct HowToPlayView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "How to play",
                         eyebrow: "The rule",
                         subtitle: "One rule, endlessly awkward") {
                router.pop()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.wide) {
                    DemoStrip()

                    rule(number: 1,
                         title: "Every line is an even blend",
                         body: "Along any row or column of three or more, each tile sits exactly halfway between its two neighbours. No jumps, no doubling back.")

                    rule(number: 2,
                         title: "Some tiles are already fixed",
                         body: "Tiles with a small dot in the corner are given. They anchor the gradient — read outwards from them to work out what belongs where.")

                    rule(number: 3,
                         title: "Drag, or tap twice",
                         body: "Drag a tile from the shelf onto a slot, or tap the tile and then tap the slot. Dropping onto a filled slot swaps the two.")

                    rule(number: 4,
                         title: "Not every tile belongs",
                         body: "From the middle chapters on, the shelf carries decoys — colours that fit nowhere at all. Leaving one behind is part of the puzzle.")

                    rule(number: 5,
                         title: "Where lines cross, both must work",
                         body: "A tile at a crossing has to satisfy the row and the column at once. That single tile is usually the whole puzzle.")

                    Text("Stuck? The lightbulb places one correct tile for you. It costs a star, nothing else.")
                        .font(Theme.text(13))
                        .foregroundStyle(Theme.textTertiary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.bottom, Theme.Space.vast)
            }
        }
        .onAppear {
            router.backdropPalette = DifficultyCurve.profile(for: 12).previewRamp
        }
    }

    /// Numbered as a technical annotation rather than a badge: a mono figure, a
    /// hairline rule beside it, and the text carrying itself.
    private func rule(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            VStack(spacing: Theme.Space.tight) {
                Text(String(format: "%02d", number))
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 1)
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Theme.text(17, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(body)
                    .font(Theme.text(14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .staggeredAppear(index: number, perItem: 0.05)
    }
}

/// A five-tile run that keeps emptying and refilling itself, so the rule is
/// shown rather than only described.
///
/// The tiles sit flush with only the ends rounded — the same object the board
/// makes — so the demo is a picture of the thing, not an illustration of it.
@MainActor
private struct DemoStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    private static let count = 5

    private let ramp: [BlendColor] = {
        let start = BlendColor(lightness: 0.32, chroma: 0.10, hue: 268)
        let end = BlendColor(lightness: 0.82, chroma: 0.09, hue: 196)
        return (0..<Self.count).map { BlendColor.mix(start, end, Double($0) / Double(Self.count - 1)) }
    }()

    /// The middle tiles are the ones the player would have to place.
    private let gaps: Set<Int> = [1, 3]

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width / CGFloat(Self.count)
            HStack(spacing: 0) {
                ForEach(Array(ramp.enumerated()), id: \.offset) { index, colour in
                    ZStack {
                        if gaps.contains(index) && !filled {
                            SlotView(size: side, isHovered: false, isHinted: false)
                        } else {
                            TileView(colour: colour, size: side,
                                     role: gaps.contains(index) ? .placed : .clue,
                                     corners: corners(index), bleed: 0.5)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: side, height: side)
                }
            }
        }
        .frame(height: 74)
        .onAppear { start() }
        .accessibilityLabel("A five tile row blending from deep violet to pale blue, with two gaps being filled in")
    }

    private func corners(_ index: Int) -> TileCorners {
        var rounded: TileCorners = []
        if index == 0 { rounded.formUnion([.topLeading, .bottomLeading]) }
        if index == Self.count - 1 { rounded.formUnion([.topTrailing, .bottomTrailing]) }
        return rounded
    }

    private func start() {
        guard !reduceMotion else { filled = true; return }
        Task { await cycle() }
    }

    private func cycle() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(Motion.settle) { filled = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.3)) { filled = false }
        }
    }
}
