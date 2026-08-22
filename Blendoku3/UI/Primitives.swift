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

/// The one surface in the app.
///
/// Every panel, button, shelf and well is this: a shape filled with *exactly
/// the ground colour behind it*, made visible only by a dark shadow falling one
/// way and a light one falling the other. Nothing is outlined. An edge here is
/// a lighting result, which is why the whole chrome can be a single value in
/// each theme — all white on paper, all black on ink — and still have a legible
/// hierarchy of depth.
///
/// `pressed` flips the lighting inside the shape instead of outside it, which
/// is what turns a button into a hole. Because it is the same two shadows
/// either way, a press is a continuous animation between the two states rather
/// than a swap between two different looks.
@MainActor
struct SoftSurface<S: Shape>: View {
    var shape: S
    /// How far the surface stands off the page. Also drives the offset, so one
    /// number controls the whole extrusion.
    var depth: CGFloat = 9
    var pressed = false
    var fill: Color = Theme.ground
    /// An optional wash of colour for transient state — a live drop target, a
    /// hint. State that has to be *noticed* cannot be carried by depth alone.
    var glow: Color? = nil

    private var offset: CGFloat { depth * 0.58 }

    var body: some View {
        Group {
            if pressed {
                shape.fill(
                    fill
                        .shadow(.inner(color: Theme.shadowDeep, radius: depth * 0.72,
                                       x: offset, y: offset))
                        .shadow(.inner(color: Theme.shadowLift, radius: depth * 0.72,
                                       x: -offset, y: -offset))
                )
            } else {
                shape
                    .fill(fill)
                    .compositingGroup()
                    .shadow(color: Theme.shadowDeep, radius: depth, x: offset, y: offset)
                    .shadow(color: Theme.shadowLift, radius: depth, x: -offset, y: -offset)
            }
        }
        .overlay {
            if let glow {
                shape.fill(glow.opacity(0.18))
            }
        }
        .animation(Motion.quick, value: pressed)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts a soft surface behind this view. The shape is passed in rather than
    /// assumed, because the shelf, the pills and the wells all want different
    /// ones and every single one of them is drawn the same way.
    @MainActor
    func softSurface<S: Shape>(_ shape: S,
                               depth: CGFloat = 9,
                               pressed: Bool = false,
                               fill: Color = Theme.ground,
                               glow: Color? = nil) -> some View {
        background {
            SoftSurface(shape: shape, depth: depth, pressed: pressed,
                        fill: fill, glow: glow)
        }
    }
}

/// A sheet raised off the page. The app's dominant container.
@MainActor
struct SoftPanel<Content: View>: View {
    var radius: CGFloat = Theme.Radius.panel
    var padding: CGFloat = Theme.Space.base
    var depth: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .softSurface(RoundedRectangle(cornerRadius: radius, style: .continuous),
                         depth: depth)
    }
}

/// The finished blend, as one continuous ribbon.
///
/// Discrete cells are the right object while you are *playing* — the puzzle is
/// about judging one against the next, and the boundary is what makes the
/// judgement possible. Once it is solved that boundary has done its job, and
/// the only thing it still does is stand between the player and the blend they
/// built. So the ribbon dissolves it: same colours, no edges.
///
/// The interpolation is done here in Oklab and handed to SwiftUI as many small
/// stops, because a SwiftUI gradient blends in device RGB — which is the exact
/// failure this whole game is built to avoid. Blending two Oklab-adjacent
/// colours through sRGB bows the ramp and puts a dull band in the middle.
@MainActor
struct GradientRibbon: View {
    let colours: [BlendColor]
    var height: CGFloat = 92
    var radius: CGFloat = 14

    /// Enough stops that the sRGB interpolation SwiftUI does *between* them is
    /// too short to bend. Sixty-four across a phone width is under two points
    /// per stop.
    static let resolution = 64

    nonisolated static func ramp(_ colours: [BlendColor],
                                steps: Int = 64) -> [BlendColor] {
        let sorted = ordered(colours)
        guard let first = sorted.first else { return [] }
        guard sorted.count > 1, steps > 1 else {
            return Array(repeating: first, count: max(1, steps))
        }
        return (0..<steps).map { index in
            let t = Double(index) / Double(steps - 1) * Double(sorted.count - 1)
            let low = min(Int(t), sorted.count - 2)
            return BlendColor.mix(sorted[low], sorted[low + 1], t - Double(low))
        }
    }

    /// Sorted by lightness. A board is several independent shapes, so the cells
    /// in reading order jump between gradients and would come out as a ribbon
    /// that doubles back on itself. Lightness is the axis the generator spends
    /// most of its budget on, so ordering by it recovers the ramp the palette
    /// was cut from.
    nonisolated private static func ordered(_ colours: [BlendColor]) -> [BlendColor] {
        colours.sorted { $0.l < $1.l }
    }

    var body: some View {
        LinearGradient(colors: Self.ramp(colours, steps: Self.resolution).map(Color.init),
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }

    /// The same ramp as a CSS declaration.
    ///
    /// Written out as explicit hex stops rather than as `in oklab`, so it lands
    /// the same in any browser: with a stop every few percent there is no room
    /// left for a differently-interpolating renderer to disagree.
    nonisolated static func css(_ colours: [BlendColor], steps: Int = 12) -> String {
        let sampled = ramp(colours, steps: max(2, steps))
        guard sampled.count > 1 else { return "" }
        let stops = sampled.enumerated().map { index, colour in
            let percent = Double(index) / Double(sampled.count - 1) * 100
            return "\(colour.hexString) \(String(format: "%.1f", percent))%"
        }
        return "linear-gradient(90deg, " + stops.joined(separator: ", ") + ")"
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
