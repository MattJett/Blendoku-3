import SwiftUI

/// The primary action.
///
/// Soft UI has no filled buttons, because a fill is a second colour and the
/// whole point is that there is only one. What marks this as the primary
/// action instead is that it stands *further* off the page than anything
/// around it, and that its label is set at full contrast. Pressing it drives
/// the extrusion inward, so the button really goes down under the finger
/// rather than dimming and shrinking in place.
@MainActor
struct PillButtonStyle: ButtonStyle {
    var wide = true
    /// A small chip of colour on the leading edge, used to tie a button to the
    /// level it opens. The one place a chrome control carries a hue.
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
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 17)
        .padding(.horizontal, Theme.Space.wide)
        .frame(maxWidth: wide ? .infinity : nil)
        .softSurface(Capsule(style: .continuous),
                     depth: 11,
                     pressed: configuration.isPressed)
    }
}

/// A secondary action. The same surface, standing off the page about half as
/// far — near enough to the ground that it recedes until you look for it.
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
            .softSurface(Capsule(style: .continuous),
                         depth: 6,
                         pressed: configuration.isPressed)
    }
}

/// Small round icon button used across the HUD.
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
        }
        .buttonStyle(SoftCircleStyle())
        .accessibilityLabel(label)
    }
}

@MainActor
struct SoftCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .softSurface(Circle(), depth: 7, pressed: configuration.isPressed)
    }
}
