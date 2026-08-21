import SwiftUI

/// The moment a hundred levels close.
///
/// Deliberately the quietest screen in the game. Everything else here has
/// something to do — a board to read, a tray to pick from, a button that is
/// clearly the next thing. This has one line of type, one ribbon, and one way
/// onward, and it takes its time arriving. A hundred boards is a long argument
/// about looking carefully; the reward for finishing it should not be a
/// fanfare, it should be the whole palette at once with nothing on top of it.
@MainActor
struct ArcCompleteView: View {
    let arc: Chromarc

    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lit = false
    @State private var settled = false

    /// The arc's whole range, sampled far more finely than any single board —
    /// this is the only place the player sees the curve itself rather than a
    /// slice of it.
    private var ramp: [BlendColor] {
        stride(from: 1, through: DifficultyCurve.levelCount, by: 4).flatMap { level in
            DifficultyCurve.profile(for: level, arc: arc.number).previewRamp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: Theme.Space.base) {
                MoodLabel("Chromarc \(String(format: "%02d", arc.number)) complete")
                    .opacity(lit ? 1 : 0)

                Text(arc.title)
                    .font(Theme.display(46))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Theme.textPrimary)
                    .opacity(lit ? 1 : 0)
                    .offset(y: lit ? 0 : 14)

                Text("A hundred blends, end to end.")
                    .font(Theme.text(15))
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(settled ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Space.margin)

            Spacer(minLength: Theme.Space.vast)

            // Full bleed, no rounding, no panel: the one time the colour is not
            // held inside anything.
            GradientRibbon(colours: ramp, height: 140, radius: 0)
                .opacity(settled ? 1 : 0)
                .scaleEffect(x: settled ? 1 : 0.7, anchor: .leading)

            Spacer(minLength: 0)

            Button("Choose a Chromarc") {
                router.replaceTop(with: .chromarcs)
            }
            .buttonStyle(PillButtonStyle())
            .padding(.horizontal, Theme.Space.margin)
            .padding(.bottom, Theme.Space.base)
            .opacity(settled ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: arrive)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chromarc \(arc.number), \(arc.title), complete")
    }

    private func arrive() {
        guard !reduceMotion else { lit = true; settled = true; return }
        withAnimation(.easeOut(duration: 0.9)) { lit = true }
        withAnimation(.easeInOut(duration: 1.6).delay(0.5)) { settled = true }
    }
}
