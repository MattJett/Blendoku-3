import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress
    @Environment(GameSettings.self) private var settings
    @Environment(SessionStore.self) private var sessions

    @State private var confirmingReset = false

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            ScreenHeader(title: "Settings", eyebrow: "Preferences") { router.pop() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.wide) {
                    group("Ground") {
                        GroundPicker(selection: $settings.appearance)
                    }

                    group("Sound and touch") {
                        VStack(spacing: 0) {
                            toggle($settings.soundEnabled, "Tones",
                                   "Each tile rings at a pitch set by how light it is. In the right place it rings clean; in the wrong place it wavers.",
                                   id: "settings.tones")
                            Hairline()
                            toggle($settings.hapticsEnabled, "Haptics",
                                   "A tap when a tile is picked up or lands.",
                                   id: "settings.haptics")
                            Hairline()
                            toggle($settings.beatEnabled, "Haptic beat",
                                   "Feel the pulse of a finished board's song.",
                                   id: "settings.beat")
                            Hairline()
                            toggle($settings.replayEnabled, "Solve replay",
                                   "A solved board plays back the order you placed it in, then climbs its whole spectrum.",
                                   id: "settings.replay")
                        }
                    }

                    group("Assists") {
                        VStack(spacing: 0) {
                            toggle($settings.showColorValues, "Colour values",
                                   "Prints each tile's hex value on the tile.",
                                   id: "settings.values")
                            Hairline()
                            toggle($settings.showGridLabels, "Announce positions",
                                   "VoiceOver reads each cell's row and column.",
                                   id: "settings.positions")
                        }
                    }

                    group("Help") {
                        HStack(spacing: Theme.Space.snug) {
                            Button {
                                router.push(.howToPlay)
                            } label: {
                                SlabLabel(title: "How to play", size: 15)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 7))
                            .accessibilityIdentifier("settings.howToPlay")

                            Button {
                                settings.replayCoaching()
                                Haptics.play(.snap)
                            } label: {
                                SlabLabel(title: settings.hasFinishedCoaching ? "Walkthrough" : "Walkthrough on",
                                          size: 15)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 7, isOn: !settings.hasFinishedCoaching))
                            .accessibilityLabel("Replay the first board's walkthrough")
                            .accessibilityValue(settings.hasFinishedCoaching ? "Off" : "On")
                        }
                    }

                    group("Progress") {
                        VStack(alignment: .leading, spacing: Theme.Space.base) {
                            HStack(spacing: Theme.Space.wide) {
                                Readout(value: String(format: "%03d", progress.completedCount), label: "solved")
                                Readout(value: "\(progress.totalStars)", label: "stars")
                                Spacer(minLength: 0)
                            }

                            Button(role: .destructive) {
                                confirmingReset = true
                            } label: {
                                SlabLabel(title: "Reset all progress", tint: Self.danger, size: 15)
                            }
                            .buttonStyle(SlabButtonStyle(depth: 7))
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.snug) {
                        Text("Levels are generated from their number, so the same level is the same puzzle on every device. Nothing is downloaded and nothing is sent anywhere.")
                            .font(Theme.text(12))
                            .foregroundStyle(Theme.textTertiary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        VersionMark()
                    }
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.bottom, Theme.Space.vast)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: settings.appearance) { _, _ in settings.persist() }
        .onChange(of: settings.soundEnabled) { _, _ in settings.persist() }
        .onChange(of: settings.hapticsEnabled) { _, _ in settings.persist() }
        .onChange(of: settings.beatEnabled) { _, _ in settings.persist() }
        .onChange(of: settings.replayEnabled) { _, _ in settings.persist() }
        .onChange(of: settings.showColorValues) { _, _ in settings.persist() }
        .onChange(of: settings.showGridLabels) { _, _ in settings.persist() }
        .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) {
                progress.resetEverything()
                sessions.clear()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Every level goes back to locked. Keepsakes stay. This cannot be undone.")
        }
        .onAppear { router.backdropPalette = DifficultyCurve.profile(for: 42).previewRamp }
    }

    private static let danger = Color(red: 0.80, green: 0.31, blue: 0.28)

    /// A mono annotation, a rule, and the rows underneath. No boxes: on a
    /// quiet ground a card outline is louder than the text it contains.
    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            MonoLabel(title)
            Hairline(tint: Theme.hairlineStrong)
            content()
        }
    }

    private func toggle(_ isOn: Binding<Bool>, _ title: String, _ detail: String,
                        id: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.control(15, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(Theme.controlTracking)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(SoftToggleStyle())
        .padding(.vertical, Theme.Space.snug)
        .accessibilityIdentifier(id)
    }
}

/// Light, shadow or automatic. Each option is its own slab; the chosen one
/// is pressed in and stays there, the way a latching switch does.
@MainActor
private struct GroundPicker: View {
    @Binding var selection: Appearance

    var body: some View {
        HStack(spacing: Theme.Space.snug) {
            ForEach(Appearance.allCases) { option in
                Button {
                    Haptics.play(.select)
                    withAnimation(Motion.tile) { selection = option }
                } label: {
                    SlabLabel(title: option.title,
                              tint: selection == option ? Theme.textPrimary : Theme.textSecondary,
                              size: 16)
                }
                .buttonStyle(SlabButtonStyle(depth: 8, isOn: selection == option))
                .accessibilityIdentifier("settings.ground.\(option.rawValue)")
                .accessibilityAddTraits(selection == option ? [.isSelected] : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ground")
    }
}
