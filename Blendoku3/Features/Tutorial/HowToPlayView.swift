import SwiftUI

@MainActor
struct HowToPlayView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "How to play", subtitle: "One rule, endlessly awkward") {
                router.pop()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    DemoStrip()
                        .frame(height: 92)
                        .padding(.horizontal, 20)

                    rule(number: 1,
                         title: "Every line is an even blend",
                         body: "Along any row or column of three or more, each tile sits exactly halfway between its two neighbours. No jumps, no doubling back.")

                    rule(number: 2,
                         title: "Some tiles are already fixed",
                         body: "Tiles with a thin inner ring are given. They anchor the gradient — read outwards from them to work out what belongs where.")

                    rule(number: 3,
                         title: "Drag, or tap twice",
                         body: "Drag a tile from the tray onto a slot, or tap the tile and then tap the slot. Dropping onto a filled slot swaps the two.")

                    rule(number: 4,
                         title: "Not every tile belongs",
                         body: "From the middle chapters on, the tray carries decoys — colours that fit nowhere at all. Leaving one behind is part of the puzzle.")

                    rule(number: 5,
                         title: "Where lines cross, both must work",
                         body: "A tile at a crossing has to satisfy the row and the column at once. That single tile is usually the whole puzzle.")

                    Text("Stuck? The lightbulb places one correct tile for you. It costs a star, nothing else.")
                        .font(Theme.display(13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
                .padding(.top, 6)
            }
        }
        .onAppear {
            router.backdropPalette = DifficultyCurve.profile(for: 12).previewRamp
        }
    }

    private func rule(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(Theme.display(14, weight: .heavy))
                .foregroundStyle(Theme.backdrop)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.accent))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(Theme.display(16))
                    .foregroundStyle(Theme.textPrimary)
                Text(body)
                    .font(Theme.display(14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .staggeredAppear(index: number, perItem: 0.05)
    }
}

/// A five-tile row that keeps emptying and refilling itself, so the rule is
/// shown rather than only described.
@MainActor
private struct DemoStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    private let ramp: [BlendColor] = {
        let start = BlendColor(lightness: 0.32, chroma: 0.10, hue: 268)
        let end = BlendColor(lightness: 0.82, chroma: 0.09, hue: 196)
        return (0..<5).map { BlendColor.mix(start, end, Double($0) / 4) }
    }()

    /// The middle tiles are the ones the player would have to place.
    private let gaps: Set<Int> = [1, 3]

    private func cycle() async {
        guard !reduceMotion else { filled = true; return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { filled = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.3)) { filled = false }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(ramp.enumerated()), id: \.offset) { index, colour in
                ZStack {
                    if gaps.contains(index) && !filled {
                        SlotView(size: 54, isHovered: false, isHinted: false)
                    } else {
                        TileView(colour: colour, size: 54,
                                 role: gaps.contains(index) ? .placed : .clue)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
                .frame(width: 54, height: 54)
            }
        }
        .frame(maxWidth: .infinity)
        .task { await cycle() }
        .accessibilityLabel("A five tile row blending from deep violet to pale blue, with two gaps being filled in")
    }
}
