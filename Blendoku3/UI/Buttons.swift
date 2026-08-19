import SwiftUI

@MainActor
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var wide = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(17, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.86))
            .padding(.vertical, 15)
            .padding(.horizontal, 26)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.gradient)
                    .shadow(color: tint.opacity(0.35), radius: configuration.isPressed ? 6 : 16,
                            x: 0, y: configuration.isPressed ? 2 : 8)
            )
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(Motion.tile, value: configuration.isPressed)
    }
}

@MainActor
struct GhostButtonStyle: ButtonStyle {
    var wide = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(16, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surfaceRaised.opacity(configuration.isPressed ? 0.9 : 0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.tile, value: configuration.isPressed)
    }
}

/// Small round icon button used across the game HUD.
@MainActor
struct CircleIconButton: View {
    let systemName: String
    var label: String
    var tint: Color = Theme.textPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(Theme.surfaceRaised.opacity(0.65))
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

@MainActor
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}
