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
            ScreenHeader(title: "Settings", subtitle: nil) { router.pop() }

            ScrollView {
                VStack(spacing: 14) {
                    card {
                        Toggle(isOn: $settings.hapticsEnabled) {
                            label("Haptics", "A tap when a tile is picked up or lands")
                        }
                        divider
                        Toggle(isOn: $settings.showColorValues) {
                            label("Show colour values", "Prints each tile's hex value on the tile")
                        }
                        divider
                        Toggle(isOn: $settings.showGridLabels) {
                            label("Announce positions", "Adds row and column numbers to VoiceOver labels")
                        }
                    }
                    .tint(Theme.accent)
                    .onChange(of: settings.hapticsEnabled) { _, _ in settings.persist() }
                    .onChange(of: settings.showColorValues) { _, _ in settings.persist() }
                    .onChange(of: settings.showGridLabels) { _, _ in settings.persist() }

                    card {
                        HStack {
                            label("Progress", "\(progress.completedCount) levels solved, \(progress.totalStars) stars")
                            Spacer()
                        }
                        divider
                        Button(role: .destructive) {
                            confirmingReset = true
                        } label: {
                            HStack {
                                Text("Reset all progress")
                                    .font(Theme.display(15, weight: .medium))
                                Spacer()
                                Image(systemName: "trash")
                            }
                            .foregroundStyle(Color(red: 0.94, green: 0.45, blue: 0.45))
                        }
                    }

                    Text("Levels are generated from their number, so the same level is the same puzzle on every device. Nothing is downloaded and nothing is sent anywhere.")
                        .font(Theme.display(12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
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

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) { content() }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1))
            )
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    private func label(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.display(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.display(12, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
