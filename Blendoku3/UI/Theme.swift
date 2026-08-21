import SwiftUI
import UIKit

extension Color {
    /// Bridges a puzzle colour onto the screen. Puzzle colours are generated
    /// inside the sRGB gamut, so the clamp here never actually bites.
    init(_ blend: BlendColor) {
        let rgb = blend.rgb.clamped
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

extension BlendColor {
    /// Black or white, whichever will be readable on top of this colour.
    var readableForeground: Color {
        l > 0.62 ? Color.black.opacity(0.78) : Color.white.opacity(0.90)
    }
}

/// The design tokens.
///
/// The system is achromatic on purpose. Every surface is a warm grey — paper
/// in light, ink in dark — and exactly one accent (ember) is allowed to be
/// saturated. Colour in this app belongs to the puzzle; if the chrome joins in,
/// the player stops being able to judge a hue against its neighbour, which is
/// the only thing the game asks them to do.
enum Theme {

    // MARK: - Ground

    /// The page itself, and every surface on it. Warm near-white, or
    /// near-black. There is deliberately only one — panels, shelves, buttons
    /// and wells are all this exact colour, and are told apart by their
    /// lighting alone. The old tinted variants (`raised`, `sunken`, `veil`)
    /// are gone with the borders they used to accompany.
    static let ground = dynamic(light: 0xEAE7E2, dark: 0x0D0F12)

    // MARK: - Line

    static let hairline = dynamic(light: 0x1A1917, dark: 0xF0EEEA).opacity(0.12)
    static let hairlineStrong = dynamic(light: 0x1A1917, dark: 0xF0EEEA).opacity(0.26)

    // MARK: - Depth

    /// Soft-UI depth. Every panel, button and well in the app is the *same
    /// colour as the ground it sits on*; what separates it is a dark shadow
    /// falling one way and a light one falling the other. There are no borders
    /// anywhere in the chrome — an edge is a lighting result, not a drawn line.
    ///
    /// The alphas are baked into the colours rather than applied at the call
    /// site, because the two grounds need very different ones: on paper the
    /// highlight is nearly opaque white and the shadow is gentle, while on ink
    /// the shadow goes to true black and the highlight has to stay faint or the
    /// surface turns to plastic.
    static let shadowDeep = dynamic(light: 0x9E978C, lightAlpha: 0.55,
                                    dark: 0x000000, darkAlpha: 0.66)
    static let shadowLift = dynamic(light: 0xFFFFFF, lightAlpha: 0.92,
                                    dark: 0x30363F, darkAlpha: 0.42)

    // MARK: - Type

    static let textPrimary = dynamic(light: 0x1A1917, dark: 0xF0EEEA)
    static let textSecondary = dynamic(light: 0x6C6862, dark: 0x8E8B85)
    /// Micro-labels and registration marks. Deliberately close to the ground.
    static let textTertiary = dynamic(light: 0x9B968F, dark: 0x5D5B56)

    // MARK: - Accent

    /// The one saturated thing in the chrome. Darker on paper so it still
    /// carries against a light ground.
    static let accent = dynamic(light: 0xB9741A, dark: 0xE9A33F)
    static let success = dynamic(light: 0x4C7A5A, dark: 0x74B48E)
    static let warning = accent

    // MARK: - Board

    static let tileCornerRatio: CGFloat = 0.20
    /// The outline an empty slot gets back when the system asks for increased
    /// contrast. Depth alone carries it the rest of the time.
    static let slotStroke = dynamic(light: 0x1A1917, dark: 0xF0EEEA).opacity(0.32)

    // MARK: - Geometry

    enum Radius {
        /// Panels and sheets. Tightened from the old stadium idiom: a brutalist
        /// surface is a slab, and a slab has corners taken off rather than
        /// corners made of arcs.
        static let panel: CGFloat = 22
        static let card: CGFloat = 16
        /// Buttons and segmented controls. The one number that decides whether
        /// the app reads as soft or as built.
        static let control: CGFloat = 13
        static let chip: CGFloat = 10
    }

    /// A 4pt-based scale with editorial jumps at the top end.
    enum Space {
        static let hair: CGFloat = 4
        static let tight: CGFloat = 8
        static let snug: CGFloat = 12
        static let base: CGFloat = 20
        static let wide: CGFloat = 32
        static let vast: CGFloat = 52
        /// The single left/right margin used by every screen.
        static let margin: CGFloat = 24
    }

    // MARK: - Type ramp

    /// The display face: the system grotesque at its narrowest cut and heaviest
    /// weight, always set in caps.
    ///
    /// No font file ships with the app. `Font.Width.compressed` gives the
    /// compressed cut of SF Pro, which is the closest thing iOS has to a
    /// brutalist grotesque without licensing one — and unlike a bundled face it
    /// carries every weight, every optical size and the full glyph set, so it
    /// scales with Dynamic Type and never falls back to something else.
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight).width(.compressed)
    }

    /// Running text and buttons.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Button and control labels: caps, tracked out, condensed a step.
    static func control(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    /// Numerals, counters and identifiers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Tracking for the tracked-out micro-caps used as section labels.
    static let labelTracking: CGFloat = 1.7
    /// Tracking for caps set at button size. Less than a micro-cap needs, since
    /// the letters are already big enough to tell apart.
    static let controlTracking: CGFloat = 1.1

    // MARK: - Helpers

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        dynamic(light: light, lightAlpha: 1, dark: dark, darkAlpha: 1)
    }

    private static func dynamic(light: UInt32, lightAlpha: CGFloat,
                                dark: UInt32, darkAlpha: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(rgb: isDark ? dark : light,
                           alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
}

/// Motion. Everything in the app draws from these four curves, so the whole
/// thing decelerates the same way no matter what you touched.
enum Motion {
    static let screen = Animation.spring(response: 0.48, dampingFraction: 0.88)
    static let tile = Animation.spring(response: 0.30, dampingFraction: 0.76)
    static let settle = Animation.spring(response: 0.38, dampingFraction: 0.64)
    static let quick = Animation.easeOut(duration: 0.16)
    /// Ambient drift, for anything that moves on its own.
    static let ambient = Animation.easeInOut(duration: 9).repeatForever(autoreverses: true)
}
