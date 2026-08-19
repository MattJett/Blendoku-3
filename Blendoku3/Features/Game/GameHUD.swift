import SwiftUI

@MainActor
struct GameHUD: View {
    let controller: GameController
    let onBack: () -> Void
    let onReset: () -> Void
    let onHint: () -> Void

    private var puzzle: Puzzle { controller.session.puzzle }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                CircleIconButton(systemName: "chevron.left", label: "Back", action: onBack)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Level \(puzzle.level)")
                        .font(Theme.display(19))
                        .foregroundStyle(Theme.textPrimary)
                    Text(puzzle.chapter.title)
                        .font(Theme.display(12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                CircleIconButton(systemName: "lightbulb.fill", label: "Hint",
                                 tint: Theme.warning, action: onHint)
                CircleIconButton(systemName: "arrow.counterclockwise", label: "Start over",
                                 action: onReset)
            }

            HStack(spacing: 10) {
                pill(icon: "square.grid.2x2", text: "\(controller.session.remainingCount) left")
                pill(icon: "arrow.left.arrow.right", text: "\(controller.session.moves) moves")
                DifficultyPips(score: DifficultyCurve.profile(for: puzzle.level).difficultyScore)
                Spacer(minLength: 0)
                ProgressRing(progress: controller.session.progress)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func pill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(Theme.display(12, weight: .medium))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.surface.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }
}

/// Five pips showing roughly how mean a level is.
@MainActor
struct DifficultyPips: View {
    let score: Double

    var body: some View {
        let filled = max(1, Int((score * 5).rounded(.up)))
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? Theme.accent.opacity(0.9) : Theme.textSecondary.opacity(0.3))
                    .frame(width: 8, height: 3.5)
            }
        }
        .accessibilityLabel("Difficulty \(filled) of 5")
    }
}

@MainActor
struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.textSecondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.tile, value: progress)
        }
        .accessibilityLabel("\(Int(progress * 100)) percent placed")
    }
}
