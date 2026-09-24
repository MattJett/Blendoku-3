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

/// A slab: the brutalist control. A raised rectangle that goes down under the
/// finger, and — for a switch like Keep — stays down while it is on.
///
/// The rule the whole interface keeps is that anything standing up off the
/// page can be pressed, and nothing else stands up. This is the shape that
/// rule takes for a control with content of its own.
@MainActor
struct SlabButtonStyle: ButtonStyle {
    var depth: CGFloat = 9
    var radius: CGFloat = Theme.Radius.control
    /// Holds the slab pressed in, for a control that is currently on.
    var isOn = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .softSurface(shape, depth: depth, pressed: isOn || configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// The standard label for a slab: a compressed word, set big, with an
/// optional mono figure under it.
@MainActor
struct SlabLabel: View {
    let title: String
    var detail: String?
    var tint: Color = Theme.textPrimary
    var size: CGFloat = 17

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Theme.display(size, weight: .black))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                MonoLabel(detail, size: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, detail == nil ? 16 : 13)
        .padding(.horizontal, 6)
    }
}

/// A switch made of the same two depths as everything else: a slot cut into
/// the page, and a block riding in it that can be pushed from one end to the
/// other. The block takes the accent when the switch is on.
@MainActor
struct SoftToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(Motion.tile) { configuration.isOn.toggle() }
            Haptics.play(.select)
        } label: {
            HStack(alignment: .center, spacing: Theme.Space.snug) {
                configuration.label
                Spacer(minLength: 0)
                track(isOn: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }

    private func track(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            SoftSurface(shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                        depth: 5, pressed: true)
            SoftSurface(shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                        depth: 4, fill: isOn ? Theme.accent : Theme.ground)
                .frame(width: 20, height: 20)
                .padding(3)
        }
        .frame(width: 48, height: 26)
    }
}
