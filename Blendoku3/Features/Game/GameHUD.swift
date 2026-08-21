import SwiftUI

/// The game header.
///
/// Two rows and a rule. The rule is the progress bar — it fills as tiles land,
/// so the board's completion is carried by the line that was already there
/// rather than by a dial parked in the corner.
@MainActor
struct GameHUD: View {
    let controller: GameController
    let onBack: () -> Void
    let onReset: () -> Void
    let onHint: () -> Void

    private var puzzle: Puzzle { controller.session.puzzle }
    private var session: GameSession { controller.session }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(alignment: .center, spacing: Theme.Space.snug) {
                IconButton(systemName: "arrow.left", label: "Back", action: onBack)

                VStack(alignment: .leading, spacing: 2) {
                    MoodLabel("\(String(format: "%02d", puzzle.chapter.rawValue)) · \(puzzle.chapter.title)",
                              size: 9)
                    Text("Level \(puzzle.level)")
                        .font(Theme.display(25))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(Theme.textPrimary)
                }

                Spacer(minLength: 0)

                IconButton(systemName: "lightbulb", label: "Hint",
                                 tint: Theme.accent, action: onHint)
                IconButton(systemName: "arrow.counterclockwise", label: "Start over",
                                 action: onReset)
            }

            HStack(spacing: Theme.Space.base) {
                counter("\(session.remainingCount)", "left")
                counter("\(session.moves)", "moves")
                Spacer(minLength: 0)
                DifficultyTicks(score: DifficultyCurve.profile(for: puzzle.level).difficultyScore)
            }

            FillRule(fraction: session.progress)
        }
        .padding(.horizontal, Theme.Space.margin)
        .padding(.top, Theme.Space.hair)
    }

    private func counter(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(Theme.mono(14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            MoodLabel(label, size: 9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

/// Five ticks showing roughly how mean a level is. Hairlines rather than
/// filled pips — it is an annotation, not a score.
@MainActor
struct DifficultyTicks: View {
    let score: Double

    var body: some View {
        let filled = max(1, Int((score * 5).rounded(.up)))
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? Theme.accent : Theme.hairlineStrong)
                    .frame(width: 6, height: index < filled ? 8 : 2)
            }
        }
        .frame(height: 8, alignment: .bottom)
        .accessibilityLabel("Difficulty \(filled) of 5")
    }
}
