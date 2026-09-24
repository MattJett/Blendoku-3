import SwiftUI
import UIKit

/// The keepsakes: finished boards the player chose to keep.
///
/// Each one is a blend and, if it was kept after songs existed, the tune the
/// player made placing it. The ribbon is inlaid in the page — it is colour to
/// look at, not something to press — and the three things that can be done
/// with it stand up beside it: play the song, copy the CSS, let it go.
@MainActor
struct KeepsakesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BlendLibrary.self) private var library

    @State private var copied: UUID?
    @State private var doomed: SavedBlend?

    private var performer: SongPerformer { .shared }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Keepsakes", eyebrow: eyebrow) {
                performer.stop()
                router.pop()
            }

            if library.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Space.wide) {
                        ForEach(library.blends) { blend in
                            entry(blend)
                        }
                    }
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.top, Theme.Space.tight)
                    .padding(.bottom, Theme.Space.vast)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onDisappear { performer.stop() }
        .confirmationDialog("Let this keepsake go?",
                            isPresented: Binding(get: { doomed != nil },
                                                 set: { if !$0 { doomed = nil } }),
                            titleVisibility: .visible,
                            presenting: doomed) { blend in
            Button("Delete \(blend.label)", role: .destructive) {
                if performer.playing == blend.id { performer.stop() }
                withAnimation(Motion.tile) { library.remove(blend) }
            }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("Its blend and its song are removed. This cannot be undone.")
        }
    }

    private var eyebrow: String {
        guard !library.isEmpty else { return "Nothing kept yet" }
        return "\(String(format: "%02d", library.blends.count)) kept · \(String(format: "%02d", library.songCount)) songs"
    }

    private var empty: some View {
        VStack(spacing: Theme.Space.snug) {
            Spacer(minLength: 0)
            Text("Nothing kept")
                .font(Theme.display(30))
                .textCase(.uppercase)
                .carved()
            Text("Solve a board and press Keep. Its blend lands here with its CSS — and the song you made placing it.")
                .font(Theme.text(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Space.wide)
    }

    // MARK: - One keepsake

    private func entry(_ blend: SavedBlend) -> some View {
        let song = blend.song
        let isPlaying = performer.playing == blend.id

        return VStack(alignment: .leading, spacing: Theme.Space.snug) {
            GradientRibbon(colours: blend.colours, height: 72, radius: 11)
                .overlay {
                    if isPlaying, let schedule = performer.schedule, let startedAt = performer.startedAt {
                        SongPlayhead(schedule: schedule, startedAt: startedAt)
                    }
                }
                .padding(6)
                .softSurface(RoundedRectangle(cornerRadius: 17, style: .continuous),
                             depth: 7, pressed: true)

            HStack(alignment: .center, spacing: Theme.Space.tight) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(blend.label)
                        .font(Theme.display(21))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(Theme.textPrimary)
                    MonoLabel(details(blend, song: song))
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 0)

                if let song {
                    IconButton(systemName: isPlaying ? "stop.fill" : "play.fill",
                               label: isPlaying ? "Stop the song" : "Play the song",
                               tint: Theme.accent) {
                        toggle(blend, song: song)
                    }
                }

                IconButton(systemName: copied == blend.id ? "checkmark" : "doc.on.doc",
                           label: "Copy the CSS") {
                    UIPasteboard.general.string = blend.css
                    Haptics.play(.snap)
                    withAnimation(Motion.quick) { copied = blend.id }
                }

                IconButton(systemName: "trash", label: "Delete this keepsake") {
                    doomed = blend
                }
            }
        }
    }

    private func details(_ blend: SavedBlend, song: SongSchedule?) -> String {
        let date = blend.savedAt.formatted(.dateTime.month(.abbreviated).day())
        guard let song else { return "Blend · \(blend.swatches.count) stops · \(date)" }
        return "Song · \(song.climb.count) cells · \(String(format: "%.1f", song.lastOnset))s · \(date)"
    }

    private func toggle(_ blend: SavedBlend, song: SongSchedule) {
        if performer.playing == blend.id {
            performer.stop()
            return
        }
        Haptics.play(.select)
        Task { await performer.perform(song, warmth: blend.warmth ?? 0.5, id: blend.id) }
    }
}
