import SwiftUI

/// The title page.
///
/// What every game opens on: the name, and an invitation to begin. The
/// wordmark is cut into the page at a size that leaves the page around it —
/// a mark sitting on a sheet, not a banner running off it — and the only
/// other things here are annotations in the corners and one line asking for a
/// tap. The whole screen is the button.
@MainActor
struct TitleView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @State private var breathing = false

    var body: some View {
        GeometryReader { proxy in
            // Six columns across a little over half the width, capped so it
            // never becomes a banner on a big phone.
            let cell = min(58, (proxy.size.width - Theme.Space.margin * 2) * 0.58 / (6 * 0.66))

            ZStack {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Wordmark(cell: cell, marksCrossing: true)
                        .opacity(shown ? 1 : 0)
                        .offset(y: shown ? 0 : 12)
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                    MonoLabel("Tap to begin", size: 10, tint: Theme.textSecondary)
                        .opacity(shown ? (breathing ? 0.95 : 0.35) : 0)
                        .padding(.bottom, proxy.size.height * 0.12)
                }
                .frame(maxWidth: .infinity)

                corners
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: begin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swatchword")
        .accessibilityHint("Begins the game")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { begin() }
        .accessibilityIdentifier("title.begin")
        .onAppear(perform: arrive)
    }

    /// Registration marks at the four corners — the technical-drawing idiom
    /// again, this time for the facts about the game rather than the board.
    private var corners: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                MonoLabel("A game of even blends")
                Spacer(minLength: Theme.Space.base)
                MonoLabel("01 / First Light")
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VersionMark()
                Spacer(minLength: Theme.Space.base)
                MonoLabel("Oklab · 220 Hz")
            }
        }
        .padding(.horizontal, Theme.Space.margin)
        .padding(.vertical, Theme.Space.tight)
        .opacity(shown ? 1 : 0)
    }

    private func arrive() {
        let profile = DifficultyCurve.profile(for: progress.furthestUnlocked)
        router.backdropPalette = profile.previewRamp
        // Tuned now, so the first note the game ever plays — the one on the
        // tap below — is already rendered and in the key of the next board.
        SoundField.shared.prepare(hue: profile.baseHue,
                                  chroma: 0.16 * profile.chromaFraction.upperBound)

        guard !reduceMotion, !Runtime.holdsStill else {
            shown = true
            breathing = true
            return
        }
        withAnimation(.easeOut(duration: 1.1)) { shown = true }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.1)) {
            breathing = true
        }
    }

    private func begin() {
        Haptics.play(.snap)
        if let colour = router.backdropPalette.dropFirst().first {
            SoundField.shared.play(.settled, for: colour)
        }
        router.begin()
    }
}
