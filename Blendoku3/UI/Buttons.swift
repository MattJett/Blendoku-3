import SwiftUI

/// The primary action. A high-contrast stadium — the moodboard's one
/// unambiguous "press this", and the only element that fully inverts the
/// ground.
@MainActor
struct PillButtonStyle: ButtonStyle {
    var wide = true
    /// A small flush chip of colour on the leading edge, used on the home
    /// screen to tie the button to the level it opens.
    var chip: Color?

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            if let chip {
                Circle()
                    .fill(chip)
                    .frame(width: 9, height: 9)
            }
            configuration.label
        }
        .font(Theme.text(16, weight: .semibold))
        .foregroundStyle(Theme.ground)
        .padding(.vertical, 17)
        .padding(.horizontal, Theme.Space.wide)
        .frame(maxWidth: wide ? .infinity : nil)
        .background(Capsule(style: .continuous).fill(Theme.textPrimary))
        .opacity(configuration.isPressed ? 0.82 : 1)
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// A secondary action. Nothing but a hairline stadium; it recedes until you
/// look for it.
@MainActor
struct OutlineButtonStyle: ButtonStyle {
    var wide = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.text(15, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 15)
            .padding(.horizontal, Theme.Space.base)
            .frame(maxWidth: wide ? .infinity : nil)
            .background {
                Capsule(style: .continuous)
                    .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
                    .background(Capsule(style: .continuous)
                        .fill(Theme.textPrimary.opacity(configuration.isPressed ? 0.06 : 0)))
            }
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// Small round icon button used across the HUD. Hairline only — on a quiet
/// ground a filled circle reads as loud as a coloured tile.
@MainActor
struct CircleIconButton: View {
    let systemName: String
    var label: String
    var tint: Color = Theme.textPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

@MainActor
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}
