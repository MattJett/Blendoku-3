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
                .frame(height: 62)
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

/// A little five-tile gradient that keeps re-blending itself, as a taste of
/// what the game asks for.
@MainActor
private struct BlendPreviewStrip: View {
    let palette: [BlendColor]
    @State private var shuffled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colours: [BlendColor] {
        guard let first = palette.first, let last = palette.last else { return [] }
        return (0..<6).map { BlendColor.mix(first, last, Double($0) / 5) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(colours.enumerated()), id: \.offset) { index, colour in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(colour))
                    .offset(y: shuffled ? offset(for: index) : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.62)
                        .delay(Double(index) * 0.05), value: shuffled)
            }
        }
        .task { await drift() }
        .accessibilityHidden(true)
    }

    private func drift() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.6))
            shuffled.toggle()
        }
    }

    private func offset(for index: Int) -> CGFloat {
        [-8, 6, -4, 9, -6, 4][index % 6]
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
