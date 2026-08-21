import SwiftUI

/// The first board's walkthrough.
///
/// Three cells and one gap is not a puzzle, it is a sentence — so the opening
/// level is spent saying what the game is rather than testing it. The card sits
/// low, above the tray and clear of the board, because every step it describes
/// happens up there and covering the thing being explained is the usual way
/// this sort of overlay fails.
///
/// It advances on its own as the player does each thing, which is the point:
/// the last step is dismissed by *solving the board*, not by tapping "done" on
/// a description of solving the board.
@MainActor
struct CoachOverlay: View {
    let step: Step
    let onSkip: () -> Void

    enum Step: Int, Comparable {
        /// Nothing picked up yet.
        case pickUp
        /// Holding a tile, nothing placed.
        case drop
        /// Placed, board not yet finished.
        case read

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }

        var title: String {
            switch self {
            case .pickUp: "Take a colour"
            case .drop: "Put it in the gap"
            case .read: "Read the line"
            }
        }

        var detail: String {
            switch self {
            case .pickUp: "Drag one out of the tray, or tap it to pick it up."
            case .drop: "Drop it on the empty square, or tap the square."
            case .read: "Every line has to shade evenly from one end to the other. If it does, the board is done."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.tight) {
            HStack(spacing: Theme.Space.snug) {
                MoodLabel("Step \(step.rawValue + 1) of 3")
                Spacer(minLength: 0)
                Button("Skip", action: onSkip)
                    .font(Theme.control(12, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(Theme.controlTracking)
                    .foregroundStyle(Theme.textTertiary)
                    .buttonStyle(.plain)
            }

            Text(step.title)
                .font(Theme.display(22))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(Theme.textPrimary)

            Text(step.detail)
                .font(Theme.text(14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // The steps are a filling rule rather than a row of dots, because
            // the game already uses exactly this line to mean "how far along".
            FillRule(fraction: Double(step.rawValue + 1) / 3)
                .padding(.top, Theme.Space.hair)
        }
        .padding(Theme.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous),
                     depth: 14)
        .padding(.horizontal, Theme.Space.margin)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(step.title). \(step.detail)")
    }
}
