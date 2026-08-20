import SwiftUI

/// The app's ground.
///
/// A flat neutral page with two or three blooms of the current level's colour
/// drifting behind it, blurred far past the point of being shapes. It replaces
/// the usual game-menu light show on purpose: the player has to judge one hue
/// against its neighbour all day, and a busy backdrop poisons that judgement.
/// What is left is atmosphere — enough to tell you the level changed, not
/// enough to argue with a tile.
@MainActor
struct PigmentField: View {
    var palette: [BlendColor]

    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var colours: [BlendColor] {
        let source = palette.isEmpty ? Self.fallback : palette
        // Three blooms is the most that still reads as a single atmosphere.
        return Array(Self.spread(source, count: 3))
    }

    /// Low on purpose. The first build of this washed the whole home screen
    /// green, which is the exact failure the design is meant to prevent: the
    /// ground has to stay neutral or there is nothing for a tile's colour to be
    /// judged against.
    ///
    /// Paper needs slightly more than ink: multiplying a bloom into a near-white
    /// page moves it far less than screening the same bloom onto a near-black
    /// one, and at ink's setting the light ground came out perfectly flat.
    private var intensity: Double { scheme == .dark ? 0.18 : 0.20 }

    var body: some View {
        GeometryReader { proxy in
            let span = max(proxy.size.width, proxy.size.height)

            ZStack {
                Theme.ground

                ZStack {
                    ForEach(Array(colours.enumerated()), id: \.offset) { index, colour in
                        PigmentOrb(colour: colour,
                                   diameter: span * Self.scales[index],
                                   intensity: intensity)
                            .position(Self.anchor(index, in: proxy.size))
                            .offset(x: drift ? Self.travel[index].width : -Self.travel[index].width,
                                    y: drift ? Self.travel[index].height : -Self.travel[index].height)
                    }
                }
                .compositingGroup()
                .blendMode(scheme == .dark ? .screen : .multiply)

                // Pulls the corners down so the content sits in a pool of light.
                RadialGradient(colors: [.clear, Theme.ground.opacity(scheme == .dark ? 0.72 : 0.34)],
                               center: .center,
                               startRadius: span * 0.20,
                               endRadius: span * 0.66)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Motion.ambient) { drift = true }
        }
        .accessibilityHidden(true)
    }

    /// Where each bloom sits before it starts drifting. Deliberately off the
    /// edges, so what you see is the falloff rather than the orb.
    private static func anchor(_ index: Int, in size: CGSize) -> CGPoint {
        switch index {
        case 0: CGPoint(x: size.width * 0.06, y: size.height * 0.08)
        case 1: CGPoint(x: size.width * 1.02, y: size.height * 0.40)
        default: CGPoint(x: size.width * 0.28, y: size.height * 1.00)
        }
    }

    /// Small enough that each bloom is a local event with clean ground around
    /// it, rather than three overlapping washes that cover the screen.
    private static let scales: [CGFloat] = [0.55, 0.44, 0.60]
    private static let travel: [CGSize] = [
        CGSize(width: 22, height: 16),
        CGSize(width: -18, height: 26),
        CGSize(width: 14, height: -20),
    ]

    /// Picks `count` colours evenly across whatever the palette gave us, so a
    /// two-colour ramp and a seven-colour one both produce three blooms.
    private static func spread(_ source: [BlendColor], count: Int) -> [BlendColor] {
        guard source.count > 1 else {
            return Array(repeating: source.first ?? fallback[0], count: count)
        }
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let position = t * Double(source.count - 1)
            let low = Int(position)
            let high = min(source.count - 1, low + 1)
            return BlendColor.mix(source[low], source[high], position - Double(low))
        }
    }

    private static let fallback: [BlendColor] = [
        BlendColor(lightness: 0.62, chroma: 0.09, hue: 42),
        BlendColor(lightness: 0.52, chroma: 0.08, hue: 268),
        BlendColor(lightness: 0.58, chroma: 0.07, hue: 196),
    ]
}
