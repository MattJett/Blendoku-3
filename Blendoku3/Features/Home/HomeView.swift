import SwiftUI

/// The main menu.
///
/// Four controls and nothing else stands up: the play block, which is also
/// the arc's progress, and three slabs under it — Arcs, Keepsakes, Settings.
/// The wordmark, the tallies and the version are all set straight onto the
/// page, because none of them can be pressed.
@MainActor
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress
    @Environment(BlendLibrary.self) private var library
    @Environment(SessionStore.self) private var sessions
    @Environment(GameSettings.self) private var settings

    private var arc: Chromarc { .first }
    private var nextLevel: Int { progress.furthestUnlocked }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.top, Theme.Space.snug)
                    .staggeredAppear(index: 0, perItem: 0.05)

                Spacer(minLength: Theme.Space.base)

                PlayBlock(arc: arc,
                          next: nextLevel,
                          solved: progress.completed(in: arc),
                          status: status,
                          action: play)
                    .frame(height: min(max(proxy.size.height * 0.40, 250), 380))
                    .padding(.horizontal, Theme.Space.margin)
                    .staggeredAppear(index: 1, perItem: 0.06, travel: 18)

                Spacer(minLength: Theme.Space.base)

                satellites
                    .padding(.horizontal, Theme.Space.margin)
                    .staggeredAppear(index: 2, perItem: 0.06)

                VersionMark()
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.top, Theme.Space.base)
                    .padding(.bottom, Theme.Space.tight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .onAppear {
            router.backdropPalette = DifficultyCurve.profile(for: nextLevel).previewRamp
        }
    }

    // MARK: - Masthead

    /// The wordmark at a size that sits on the page rather than spanning it,
    /// with the running tallies set opposite it as instrument readouts.
    private var masthead: some View {
        HStack(alignment: .top, spacing: Theme.Space.base) {
            Wordmark(cell: 21)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: Theme.Space.snug) {
                tally(String(format: "%03d", progress.completedCount), "Solved")
                tally("\(progress.totalStars)", "Stars")
                tally(String(format: "%02d", library.blends.count), "Kept")
            }
            .padding(.top, 4)
        }
    }

    private func tally(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(Theme.mono(15, weight: .light))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            MonoLabel(label, size: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Satellites

    private var satellites: some View {
        HStack(spacing: Theme.Space.snug) {
            Button {
                Haptics.play(.select)
                router.push(.chromarcs)
            } label: {
                SlabLabel(title: "Arcs", detail: String(format: "%02d", Chromarc.all.count))
            }
            .buttonStyle(SlabButtonStyle())
            .accessibilityIdentifier("home.arcs")

            Button {
                Haptics.play(.select)
                router.push(.keepsakes)
            } label: {
                SlabLabel(title: "Keepsakes", detail: String(format: "%02d", library.blends.count))
            }
            .buttonStyle(SlabButtonStyle())
            .accessibilityIdentifier("home.keepsakes")

            Button {
                Haptics.play(.select)
                router.push(.settings)
            } label: {
                SlabLabel(title: "Settings", detail: settings.appearance.title)
            }
            .buttonStyle(SlabButtonStyle())
            .accessibilityIdentifier("home.settings")
        }
    }

    // MARK: - Playing

    private var status: PlayBlock.Status {
        if progress.isArcComplete { return .complete }
        if sessions.snapshot(arc: arc.number, level: nextLevel) != nil { return .resume }
        return progress.completedCount == 0 ? .start : .next
    }

    private func play() {
        Haptics.play(.snap)
        // With the whole arc done there is no next board to open; the arc
        // chooser is where the player picks what to replay.
        if progress.isArcComplete {
            router.push(.chromarcs)
        } else {
            router.push(.game(nextLevel))
        }
    }
}
