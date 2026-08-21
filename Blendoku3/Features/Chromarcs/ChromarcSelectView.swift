import SwiftUI

/// Which hundred to play.
///
/// One card per arc, each carrying a strip of the colours that arc is cut
/// from, so the choice is made by looking rather than by reading. An arc that
/// is not built yet is shown as a well pressed into the page — the same shape
/// a locked level takes, so "not yet" already has a vocabulary here.
@MainActor
struct ChromarcSelectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Chromarcs", eyebrow: "Collections") { router.pop() }

            ScrollView {
                VStack(spacing: Theme.Space.base) {
                    ForEach(Chromarc.all) { arc in
                        card(arc)
                    }
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.vertical, Theme.Space.base)
            }
        }
    }

    private func card(_ arc: Chromarc) -> some View {
        let done = arc.isPlayable ? progress.completedCount : 0

        return Button {
            guard arc.isPlayable else { return }
            router.push(.levels)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.snug) {
                HStack(alignment: .firstTextBaseline) {
                    MoodLabel("Chromarc \(String(format: "%02d", arc.number))")
                    Spacer(minLength: 0)
                    if !arc.isPlayable {
                        MoodLabel("Not yet")
                    }
                }

                Text(arc.title)
                    .font(Theme.display(30))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(arc.isPlayable ? Theme.textPrimary : Theme.textTertiary)

                GradientRibbon(colours: arc.previewRamp(steps: 40), height: 46, radius: 10)
                    .opacity(arc.isPlayable ? 1 : 0.28)
                    .saturation(arc.isPlayable ? 1 : 0.15)

                HStack(spacing: Theme.Space.base) {
                    Readout(value: "\(done)/\(DifficultyCurve.levelCount)", label: "solved", size: 15)
                    Spacer(minLength: 0)
                }
                .opacity(arc.isPlayable ? 1 : 0.4)
            }
            .padding(Theme.Space.base)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ArcCardStyle(playable: arc.isPlayable))
        .disabled(!arc.isPlayable)
        .accessibilityLabel(arc.isPlayable
                            ? "Chromarc \(arc.number), \(arc.title), \(done) of 100 solved"
                            : "Chromarc \(arc.number), \(arc.title), not available yet")
    }

}

/// Raised while it can be played, pressed into the page while it cannot.
@MainActor
private struct ArcCardStyle: ButtonStyle {
    let playable: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous),
                         depth: playable ? 12 : 8,
                         pressed: !playable || configuration.isPressed)
    }
}
