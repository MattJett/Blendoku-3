import SwiftUI

// MARK: - Micro-typography

/// A tracked-out micro-cap. The app's only section-label device.
///
/// Set small, spaced wide and kept close in value to the ground, so it reads as
/// an annotation on the page rather than as another thing competing for
/// attention with the colour.
@MainActor
struct MoodLabel: View {
    let text: String
    var size: CGFloat = 10
    var tint: Color = Theme.textTertiary

    init(_ text: String, size: CGFloat = 10, tint: Color = Theme.textTertiary) {
        self.text = text
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.text(size, weight: .semibold))
            .kerning(Theme.labelTracking)
            .foregroundStyle(tint)
    }
}

// MARK: - Hairline instrumentation

/// A one-pixel rule. Always a true pixel, never a scaled point.
@MainActor
struct Hairline: View {
    var tint: Color = Theme.hairline
    @Environment(\.displayScale) private var scale

    var body: some View {
        Rectangle()
            .fill(tint)
            .frame(height: 1 / max(1, scale))
            .accessibilityHidden(true)
    }
}

/// A crosshair registration mark, borrowed from technical drawing. Used at the
/// corners of the board to frame it without drawing a box around it.
@MainActor
struct RegistrationMark: View {
    var length: CGFloat = 9
    var tint: Color = Theme.hairlineStrong

    var body: some View {
        ZStack {
            Rectangle().fill(tint).frame(width: length, height: 1)
            Rectangle().fill(tint).frame(width: 1, height: length)
        }
        .frame(width: length, height: length)
        .accessibilityHidden(true)
    }
}

// MARK: - Pigment

/// A soft radial bloom of a single puzzle colour.
///
/// This is the only place the chrome is allowed to be saturated, and it is
/// always blurred past the point of being a shape — colour as atmosphere, so
/// the eye never tries to compare it to a tile.
@MainActor
struct PigmentOrb: View {
    let colour: BlendColor
    var diameter: CGFloat
    var intensity: Double = 0.55

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(colour).opacity(intensity),
                             Color(colour).opacity(intensity * 0.34),
                             Color(colour).opacity(0)],
                    center: .center, startRadius: 0, endRadius: diameter * 0.5)
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.16)
            .accessibilityHidden(true)
    }
}

/// Fine vertical striation, the texture that runs through the moodboard's
/// colour fields. Static, drawn once, and barely there.
@MainActor
struct Striation: View {
    var spacing: CGFloat = 3
    var opacity: Double = 0.05

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            let shading = GraphicsContext.Shading.color(.black.opacity(opacity))
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                             with: shading)
                x += spacing
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Surfaces

/// A frosted panel over whatever is behind it.
///
/// The moodboard's dominant container: a large, softly-rounded sheet of glass
/// with a single hairline edge and no shadow to speak of.
@MainActor
struct GlassPanel<Content: View>: View {
    var radius: CGFloat = Theme.Radius.panel
    var padding: CGFloat = Theme.Space.base
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Theme.veil.opacity(0.42))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    }
            }
    }
}

/// A flush run of colour with only its two ends rounded — the app's signature
/// object, and the shape the board itself makes.
@MainActor
struct SwatchBar: View {
    let colours: [BlendColor]
    var height: CGFloat = 30
    var radius: CGFloat = 8

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colours.enumerated()), id: \.offset) { index, colour in
                Rectangle()
                    .fill(Color(colour))
                    .frame(maxWidth: .infinity)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: index == 0 ? radius : 0,
                            bottomLeadingRadius: index == 0 ? radius : 0,
                            bottomTrailingRadius: index == colours.count - 1 ? radius : 0,
                            topTrailingRadius: index == colours.count - 1 ? radius : 0,
                            style: .continuous))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Readouts

/// A number set large in monospace with a micro-cap underneath it. The
/// instrument-panel readout the moodboard keeps returning to.
@MainActor
struct Readout: View {
    let value: String
    let label: String
    var size: CGFloat = 20
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(value)
                .font(Theme.mono(size, weight: .light))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            MoodLabel(label, size: 9)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

/// A hairline that fills from the leading edge.
///
/// Used both for the hundred-level progress on the home screen and for the
/// rule under the game header, which means the board's completion is shown by
/// the same line that separates the header from it — one object doing two jobs
/// instead of a widget parked in a corner.
@MainActor
struct FillRule: View {
    let fraction: Double
    var thickness: CGFloat = 2
    var tint: Color = Theme.accent
    var track: Color = Theme.hairline

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
                    .animation(Motion.tile, value: fraction)
            }
        }
        .frame(height: thickness)
        .accessibilityLabel("\(Int(fraction * 100)) percent")
    }
}
