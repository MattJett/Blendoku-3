import SwiftUI

@MainActor
struct VictoryOverlay: View {
    let puzzle: Puzzle
    let record: LevelRecord
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onReplay: () -> Void
    let onLevels: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.55 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ConfettiBurst(palette: puzzle.paletteSwatches(count: 6), seed: puzzle.seed)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Blended")
                        .font(Theme.display(30, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Level \(puzzle.level) · \(puzzle.chapter.title)")
                        .font(Theme.display(13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                AnimatedStars(count: record.stars)

                HStack(spacing: 8) {
                    ForEach(Array(puzzle.paletteSwatches(count: 7).enumerated()), id: \.offset) { index, colour in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(colour))
                            .frame(height: 26)
                            .staggeredAppear(index: index, perItem: 0.05, travel: 8)
                    }
                }
                .padding(.horizontal, 6)

                HStack(spacing: 20) {
                    stat("\(record.moves)", "moves")
                    stat(timeText, "time")
                    stat("\(puzzle.slots.count)", "tiles")
                }

                VStack(spacing: 10) {
                    if hasNextLevel {
                        Button("Next level") { onNext() }
                            .buttonStyle(PrimaryButtonStyle(
                                tint: Color(puzzle.paletteSwatches(count: 3).last ?? BlendColor(lightness: 0.7, chroma: 0.1, hue: 200))))
                    }
                    HStack(spacing: 10) {
                        Button("Replay") { onReplay() }
                            .buttonStyle(GhostButtonStyle())
                        Button("Levels") { onLevels() }
                            .buttonStyle(GhostButtonStyle())
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
            )
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 28)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { appeared = true }
        }
    }

    private var timeText: String {
        let seconds = Int(record.seconds.rounded())
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.display(19))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.display(11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct AnimatedStars: View {
    let count: Int
    @State private var shown = 0

    private func pop() async {
        for index in 0..<3 {
            try? await Task.sleep(for: .milliseconds(index == 0 ? 180 : 130))
            withAnimation(.spring(response: 0.36, dampingFraction: 0.5)) { shown = index + 1 }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(index < count ? Theme.warning : Theme.textSecondary.opacity(0.35))
                    .scaleEffect(index < shown ? 1 : 0.4)
                    .opacity(index < shown ? 1 : 0.25)
                    .rotationEffect(.degrees(index < shown ? 0 : -35))
            }
        }
        .task { await pop() }
        .accessibilityLabel("\(count) of 3 stars")
    }
}
