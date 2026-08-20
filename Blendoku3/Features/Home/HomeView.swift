import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress

    private var nextLevel: Int { progress.furthestUnlocked }
    private var palette: [BlendColor] { DifficultyCurve.profile(for: nextLevel).previewRamp }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                GradientWordmark(palette: palette)
                    .staggeredAppear(index: 0, perItem: 0.08)

                Text("Slide every tile until the colours blend evenly, end to end.")
                    .font(Theme.display(15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
                    .staggeredAppear(index: 1, perItem: 0.08)
            }

            Spacer(minLength: 20)

            BlendPreviewStrip(palette: palette)
                .frame(height: 104)
                .padding(.horizontal, 34)
                .staggeredAppear(index: 2, perItem: 0.08)

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                Button {
                    router.push(.game(nextLevel))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: progress.completedCount > 0 ? "play.fill" : "sparkles")
                        Text(progress.completedCount > 0 ? "Continue · Level \(nextLevel)" : "Start playing")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: Color(palette.last ?? palette[0])))
                .staggeredAppear(index: 3, perItem: 0.06)

                Button("Choose a level") { router.push(.levels) }
                    .buttonStyle(GhostButtonStyle())
                    .staggeredAppear(index: 4, perItem: 0.06)

                HStack(spacing: 12) {
                    Button("How to play") { router.push(.howToPlay) }
                        .buttonStyle(GhostButtonStyle())
                    Button {
                        router.push(.settings)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(GhostButtonStyle(wide: false))
                }
                .staggeredAppear(index: 5, perItem: 0.06)
            }
            .padding(.horizontal, 28)

            ProgressSummary(completed: progress.completedCount,
                            total: DifficultyCurve.levelCount,
                            stars: progress.totalStars)
                .padding(.top, 22)
                .padding(.bottom, 12)
                .staggeredAppear(index: 6, perItem: 0.06)
        }
        .onAppear { router.backdropPalette = palette }
    }
}

/// The title, masked with the palette of whatever level is up next.
@MainActor
private struct GradientWordmark: View {
    let palette: [BlendColor]
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("BLENDOKU")
            .font(.system(size: 44, weight: .heavy, design: .rounded))
            .kerning(4)
            .overlay {
                LinearGradient(colors: palette.map { Color($0) } + palette.reversed().map { Color($0) },
                               startPoint: sweep ? .topLeading : .bottomTrailing,
                               endPoint: sweep ? .bottomTrailing : .topLeading)
            }
            .mask {
                Text("BLENDOKU")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .kerning(4)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                    sweep = true
                }
            }
            .accessibilityLabel("Blendoku")
    }
}

/// A six-tile blend that keeps taking one tile out and dropping it back.
///
/// The tiles sit flush, exactly as they do on the board, so the front door
/// shows the moment the whole game is built around: the gap closing and the
/// gradient becoming continuous again.
@MainActor
private struct BlendPreviewStrip: View {
    let palette: [BlendColor]

    @State private var liftedIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let count = 6

    private var colours: [BlendColor] {
        guard let first = palette.first, let last = palette.last else { return [] }
        return (0..<count).map { BlendColor.mix(first, last, Double($0) / Double(count - 1)) }
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width / CGFloat(count), proxy.size.height * 0.58)

            HStack(spacing: 0) {
                ForEach(Array(colours.enumerated()), id: \.offset) { index, colour in
                    cell(index: index, colour: colour, side: side)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task { await cycle() }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cell(index: Int, colour: BlendColor, side: CGFloat) -> some View {
        let lifted = liftedIndex == index

        ZStack {
            // Only visible once the tile above it has moved out of the way.
            SlotView(size: side, isHovered: false, isHinted: false)
                .opacity(lifted ? 1 : 0)

            TileView(colour: colour, size: side, role: .placed,
                     corners: corners(for: index), bleed: 0.5)
                .offset(y: lifted ? -side * 0.46 : 0)
                .scaleEffect(lifted ? 1.06 : 1)
                .shadow(color: .black.opacity(lifted ? 0.5 : 0),
                        radius: lifted ? 14 : 0, y: lifted ? 9 : 0)
        }
        .frame(width: side, height: side)
        .zIndex(lifted ? 1 : 0)
    }

    /// Only the two ends of the strip round, so the six read as one bar.
    private func corners(for index: Int) -> TileCorners {
        var rounded: TileCorners = []
        if index == 0 { rounded.formUnion([.topLeading, .bottomLeading]) }
        if index == count - 1 { rounded.formUnion([.topTrailing, .bottomTrailing]) }
        return rounded
    }

    private func cycle() async {
        guard !reduceMotion else { return }
        var step = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1700))
            // Never the end tiles — a hole in the middle reads as a gap in the
            // blend, which is the thing worth showing.
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                liftedIndex = 1 + step % (count - 2)
            }
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(.spring(response: 0.44, dampingFraction: 0.70)) {
                liftedIndex = nil
            }
            step += 1
        }
    }
}

@MainActor
private struct ProgressSummary: View {
    let completed: Int
    let total: Int
    let stars: Int

    var body: some View {
        HStack(spacing: 22) {
            stat(value: "\(completed)/\(total)", label: "solved")
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 26)
            stat(value: "\(stars)", label: "stars", icon: "star.fill")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Theme.surface.opacity(0.55))
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
        )
    }

    private func stat(value: String, label: String, icon: String? = nil) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.warning)
                }
                Text(value)
                    .font(Theme.display(17))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(label)
                .font(Theme.display(11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
