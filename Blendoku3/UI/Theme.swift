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

    /// The page itself. Warm near-white, or near-black.
    static let ground = dynamic(light: 0xEAE7E2, dark: 0x0D0F12)
    /// A shade deeper than the ground, for wells and insets.
    static let sunken = dynamic(light: 0xDEDAD3, dark: 0x08090B)
    /// A shade lighter, for rails and panels that need to separate.
    static let raised = dynamic(light: 0xF3F1ED, dark: 0x171A1F)
    /// Translucent fill for glass panels sitting over colour.
    static let veil = dynamic(light: 0xFFFFFF, dark: 0x1B1F25)

    // MARK: - Line

    static let hairline = dynamic(light: 0x1A1917, dark: 0xF0EEEA).opacity(0.12)
    static let hairlineStrong = dynamic(light: 0x1A1917, dark: 0xF0EEEA).opacity(0.26)

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
    /// The empty slot. A well cut into the ground rather than a floating box —
    /// the tiles around it stay flush, so the run still reads as one bar.
    static let slotFill = dynamic(light: 0x1A1917, dark: 0x000000).opacity(0.07)
    static let slotFillHover = dynamic(light: 0x1A1917, dark: 0x000000).opacity(0.16)
    static let slotStroke = dynamic(light: 0x1A1917, dark: 0xF0EEEA).opacity(0.20)

    // MARK: - Geometry

    enum Radius {
        /// Panels and sheets. Generous, in the moodboard's stadium idiom.
        static let panel: CGFloat = 30
        static let card: CGFloat = 20
        static let chip: CGFloat = 12
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

    /// Large, light and tightly tracked. The one oversized element on a screen.
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Running text and buttons.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Numerals, counters and identifiers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Tracking for the tracked-out micro-caps used as section labels.
    static let labelTracking: CGFloat = 1.7

    // MARK: - Helpers

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
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
