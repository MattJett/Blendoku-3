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
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(chip)
                    .frame(width: 10, height: 10)
            }
            configuration.label
        }
        .font(Theme.control(15, weight: .bold))
        .textCase(.uppercase)
        .tracking(Theme.controlTracking)
        .foregroundStyle(Theme.textPrimary)
        .padding(.vertical, 17)
        .padding(.horizontal, Theme.Space.wide)
        .frame(maxWidth: wide ? .infinity : nil)
        .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous),
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
            .font(Theme.control(14, weight: .semibold))
            .textCase(.uppercase)
            .tracking(Theme.controlTracking)
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 15)
            .padding(.horizontal, Theme.Space.base)
            .frame(maxWidth: wide ? .infinity : nil)
            .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous),
                         depth: 6,
                         pressed: configuration.isPressed)
    }
}

/// The small icon button used across the HUD. A rounded square rather than a
/// disc, so it belongs to the same family as everything else the finger can
/// press — there are no circles and no stadiums in the chrome any more.
@MainActor
struct IconButton: View {
    let systemName: String
    var label: String
    var tint: Color = Theme.textPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(SoftIconStyle())
        .accessibilityLabel(label)
    }
}

@MainActor
struct SoftIconStyle: ButtonStyle {
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .softSurface(shape, depth: 7, pressed: configuration.isPressed)
    }
}
