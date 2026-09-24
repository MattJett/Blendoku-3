import SwiftUI

/// The pause menu.
///
/// The board goes under the page while it is up — the clock has stopped, so
/// the puzzle should not be sitting there to be studied — and everything the
/// player might want mid-level is one press away: carry on, start over, the
/// rules, the level list, home, and the two switches people reach for most.
@MainActor
struct PauseOverlay: View {
    let puzzle: Puzzle
    let elapsed: TimeInterval
    let moves: Int
    let remaining: Int
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHowToPlay: () -> Void
    let onLevels: () -> Void
    let onHome: () -> Void

    @Environment(GameSettings.self) private var settings
    @State private var confirmingRestart = false

    var body: some View {
        ZStack {
            // Opaque enough to hide the board, and it takes every touch so
            // nothing underneath can be moved while the clock is stopped.
            Theme.ground.opacity(0.97)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.base) {
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel("Level \(String(format: "%03d", puzzle.level)) · \(puzzle.chapter.title)")
                            Text("Paused")
                                .font(Theme.display(64))
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .carved()
                                .accessibilityAddTraits(.isHeader)
                        }

                        HStack(spacing: Theme.Space.wide) {
                            Readout(value: clock, label: "time")
                            Readout(value: "\(moves)", label: "moves")
                            Readout(value: "\(remaining)", label: "left")
                            Spacer(minLength: 0)
                        }

                        Button(action: onResume) {
                            SlabLabel(title: "Resume", tint: Theme.accent, size: 24)
                        }
                        .buttonStyle(SlabButtonStyle(depth: 12))
                        .accessibilityIdentifier("pause.resume")

                        HStack(spacing: Theme.Space.snug) {
                            Button {
                                if moves > 0 { confirmingRestart = true } else { onRestart() }
                            } label: {
                                SlabLabel(title: "Restart", size: 16)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 8))
                            .accessibilityIdentifier("pause.restart")

                            Button(action: onHowToPlay) {
                                SlabLabel(title: "How to play", size: 16)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 8))
                            .accessibilityIdentifier("pause.howToPlay")
                        }

                        HStack(spacing: Theme.Space.snug) {
                            Button(action: onLevels) {
                                SlabLabel(title: "Levels", size: 16)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 8))
                            .accessibilityIdentifier("pause.levels")

                            Button(action: onHome) {
                                SlabLabel(title: "Home", size: 16)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 8))
                            .accessibilityIdentifier("pause.home")
                        }

                        switches
                    }
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.vertical, Theme.Space.wide)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .confirmationDialog("Start this board over?", isPresented: $confirmingRestart,
                            titleVisibility: .visible) {
            Button("Start over", role: .destructive, action: onRestart)
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Every tile goes back to the tray.")
        }
    }

    /// Latching slabs: pressed in while on.
    private var switches: some View {
        @Bindable var settings = settings

        return VStack(alignment: .leading, spacing: Theme.Space.snug) {
            MonoLabel("Quick switches")
            HStack(spacing: Theme.Space.snug) {
                latch("Tones", isOn: $settings.soundEnabled, id: "pause.tones")
                latch("Haptics", isOn: $settings.hapticsEnabled, id: "pause.haptics")
                latch("Replay", isOn: $settings.replayEnabled, id: "pause.replay")
            }
        }
        .padding(.top, Theme.Space.tight)
    }

    private func latch(_ title: String, isOn: Binding<Bool>, id: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            settings.persist()
            Haptics.play(.select)
        } label: {
            SlabLabel(title: title, detail: isOn.wrappedValue ? "On" : "Off",
                      tint: isOn.wrappedValue ? Theme.textPrimary : Theme.textTertiary, size: 14)
        }
        .buttonStyle(SlabButtonStyle(depth: 7, isOn: isOn.wrappedValue))
        .accessibilityIdentifier(id)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
    }

    private var clock: String {
        let seconds = Int(elapsed.rounded(.down))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
