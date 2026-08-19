import SwiftUI

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
        l > 0.62 ? Color.black.opacity(0.72) : Color.white.opacity(0.86)
    }
}

enum Theme {
    static let backdrop = Color(red: 0.035, green: 0.039, blue: 0.055)
    static let surface = Color(red: 0.086, green: 0.094, blue: 0.122)
    static let surfaceRaised = Color(red: 0.125, green: 0.137, blue: 0.176)
    static let hairline = Color.white.opacity(0.10)
    static let textPrimary = Color(red: 0.945, green: 0.953, blue: 0.976)
    static let textSecondary = Color(red: 0.588, green: 0.627, blue: 0.706)
    static let accent = Color(red: 0.451, green: 0.780, blue: 0.925)
    static let success = Color(red: 0.435, green: 0.847, blue: 0.612)
    static let warning = Color(red: 0.976, green: 0.671, blue: 0.365)

    static let tileCornerRatio: CGFloat = 0.24

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Screen-to-screen motion. One curve for the whole app keeps it coherent.
enum Motion {
    static let screen = Animation.spring(response: 0.44, dampingFraction: 0.86)
    static let tile = Animation.spring(response: 0.30, dampingFraction: 0.74)
    static let settle = Animation.spring(response: 0.36, dampingFraction: 0.62)
    static let quick = Animation.easeOut(duration: 0.18)
}
