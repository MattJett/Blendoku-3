import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress
    @Environment(GameSettings.self) private var settings

    @State private var confirmingReset = false

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            ScreenHeader(title: "Settings", eyebrow: "Preferences") { router.pop() }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.wide) {
                    group("Appearance") {
                        AppearancePicker(selection: $settings.appearance)
                            .onChange(of: settings.appearance) { _, _ in settings.persist() }
                    }

                    group("Play") {
                        VStack(spacing: 0) {
                            row {
                                Toggle(isOn: $settings.soundEnabled) {
                                    label("Tones",
                                          "Each tile rings at a pitch set by how light it is. A tile in the right place rings clean; one in the wrong place wavers.")
                                }
                            }
                            Hairline()
                            row {
                                Toggle(isOn: $settings.hapticsEnabled) {
                                    label("Haptics", "A tap when a tile is picked up or lands")
                                }
                            }
                            Hairline()
                            row {
                                Toggle(isOn: $settings.showColorValues) {
                                    label("Show colour values", "Prints each tile's hex value on the tile")
                                }
                            }
                            Hairline()
                            row {
                                Toggle(isOn: $settings.showGridLabels) {
                                    label("Announce positions", "Adds row and column numbers to VoiceOver labels")
                                }
                            }
                        }
                        .tint(Theme.accent)
                        .onChange(of: settings.soundEnabled) { _, _ in settings.persist() }
                        .onChange(of: settings.hapticsEnabled) { _, _ in settings.persist() }
                        .onChange(of: settings.showColorValues) { _, _ in settings.persist() }
                        .onChange(of: settings.showGridLabels) { _, _ in settings.persist() }
                    }

                    group("Progress") {
                        VStack(spacing: 0) {
                            row {
                                HStack(spacing: Theme.Space.wide) {
                                    Readout(value: "\(progress.completedCount)", label: "solved")
                                    Readout(value: "\(progress.totalStars)", label: "stars")
                                    Spacer(minLength: 0)
                                }
                            }
                            Hairline()
                            row {
                                Button(role: .destructive) {
                                    confirmingReset = true
                                } label: {
                                    HStack {
                                        Text("Reset all progress")
                                            .font(Theme.text(15, weight: .medium))
                                        Spacer()
                                        Image(systemName: "trash")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundStyle(Color(red: 0.80, green: 0.31, blue: 0.28))
                                }
                            }
                        }
                    }

                    Text("Levels are generated from their number, so the same level is the same puzzle on every device. Nothing is downloaded and nothing is sent anywhere.")
                        .font(Theme.text(12))
                        .foregroundStyle(Theme.textTertiary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.bottom, Theme.Space.vast)
            }
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { progress.resetEverything() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Every level goes back to locked. This cannot be undone.")
        }
        .onAppear { router.backdropPalette = DifficultyCurve.profile(for: 42).previewRamp }
    }

    /// A tracked micro-cap, a rule, and the rows underneath. No boxes: on a
    /// quiet ground a card outline is louder than the text it contains.
    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            MoodLabel(title)
            Hairline(tint: Theme.hairlineStrong)
            content()
        }
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().padding(.vertical, Theme.Space.snug)
    }

    private func label(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.text(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.text(12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Three flush segments in a stadium — the moodboard's pill, doing a job.
@MainActor
private struct AppearancePicker: View {
    @Binding var selection: Appearance

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Appearance.allCases) { option in
                Button {
                    withAnimation(Motion.tile) { selection = option }
                } label: {
                    Text(option.title)
                        .font(Theme.control(13, weight: selection == option ? .bold : .medium))
                        .textCase(.uppercase)
                        .tracking(Theme.controlTracking)
                        .foregroundStyle(selection == option ? Theme.textPrimary : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            // The chosen option is the one thing standing up out
                            // of the trough; the others stay flush with it.
                            if selection == option {
                                SoftSurface(shape: RoundedRectangle(cornerRadius: Theme.Radius.chip,
                                                                    style: .continuous),
                                            depth: 7)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip,
                                                       style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(5)
        .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous),
                     depth: 6, pressed: true)
        .accessibilityLabel("Appearance")
    }
}
