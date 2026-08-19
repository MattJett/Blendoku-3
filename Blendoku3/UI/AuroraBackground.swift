import SwiftUI

/// Slow drifting blobs tinted with the current level's palette. Drawn in a
/// single `Canvas` and blurred once, so it stays cheap enough to leave running
/// under the whole app.
@MainActor
struct AuroraBackground: View {
    var palette: [BlendColor]
    var intensity: Double = 0.55
    var speed: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colours = palette.isEmpty ? AuroraBackground.fallback : palette

        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate * 0.055 * speed
                for (index, colour) in colours.enumerated() {
                    let phase = Double(index) * 1.87
                    let x = size.width * (0.5 + 0.40 * cos(time + phase))
                    let y = size.height * (0.44 + 0.34 * sin(time * 1.27 + phase * 1.6))
                    let radius = min(size.width, size.height) * (0.46 + 0.09 * sin(time * 0.83 + phase))
                    let centre = CGPoint(x: x, y: y)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    let shading = GraphicsContext.Shading.radialGradient(
                        Gradient(colors: [Color(colour).opacity(intensity), Color(colour).opacity(0)]),
                        center: centre, startRadius: 0, endRadius: radius)
                    context.fill(Ellipse().path(in: rect), with: shading)
                }
            }
            .blur(radius: 68)
        }
        .background(Theme.backdrop)
        .overlay(Theme.backdrop.opacity(0.28))
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private static let fallback: [BlendColor] = [
        BlendColor(lightness: 0.55, chroma: 0.11, hue: 250),
        BlendColor(lightness: 0.50, chroma: 0.10, hue: 320),
        BlendColor(lightness: 0.58, chroma: 0.09, hue: 190),
    ]
}
