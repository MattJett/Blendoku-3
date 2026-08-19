import Foundation

/// A colour stored in the Oklab perceptual colour space.
///
/// Every gradient in the game is a straight line through this space. Oklab is
/// close enough to perceptually uniform that a straight line reads as an even
/// blend, which is the property the whole puzzle rests on: the middle tile of
/// three in a row is always the arithmetic mean of its neighbours.
struct BlendColor: Hashable, Sendable {
    /// Perceptual lightness, 0 (black) ... 1 (white).
    var l: Double
    /// Green/red axis.
    var a: Double
    /// Blue/yellow axis.
    var b: Double

    init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    /// Builds a colour from cylindrical Oklab (lightness / chroma / hue).
    init(lightness: Double, chroma: Double, hue: Double) {
        let radians = hue * .pi / 180
        self.init(l: lightness, a: chroma * cos(radians), b: chroma * sin(radians))
    }

    var chroma: Double { (a * a + b * b).squareRoot() }

    var hue: Double {
        let degrees = atan2(b, a) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// Perceptual distance between two colours (Oklab units).
    func distance(to other: BlendColor) -> Double {
        let dl = l - other.l, da = a - other.a, db = b - other.b
        return (dl * dl + da * da + db * db).squareRoot()
    }

    static func + (lhs: BlendColor, rhs: BlendColor) -> BlendColor {
        BlendColor(l: lhs.l + rhs.l, a: lhs.a + rhs.a, b: lhs.b + rhs.b)
    }

    static func - (lhs: BlendColor, rhs: BlendColor) -> BlendColor {
        BlendColor(l: lhs.l - rhs.l, a: lhs.a - rhs.a, b: lhs.b - rhs.b)
    }

    static func * (lhs: BlendColor, rhs: Double) -> BlendColor {
        BlendColor(l: lhs.l * rhs, a: lhs.a * rhs, b: lhs.b * rhs)
    }

    static func / (lhs: BlendColor, rhs: Double) -> BlendColor {
        BlendColor(l: lhs.l / rhs, a: lhs.a / rhs, b: lhs.b / rhs)
    }

    static func mix(_ start: BlendColor, _ end: BlendColor, _ t: Double) -> BlendColor {
        start + (end - start) * t
    }

    /// Length of the vector, used when validating gradient step sizes.
    var magnitude: Double { (l * l + a * a + b * b).squareRoot() }
}

/// Gamma-encoded sRGB, components nominally in 0...1 but deliberately not
/// clamped so the generator can detect out-of-gamut colours.
struct RGBComponents: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    var isInsideGamut: Bool { isInsideGamut(margin: 0) }

    /// `margin` shrinks the accepted range so 8-bit rounding can never clip a
    /// generated colour and quietly break a gradient.
    func isInsideGamut(margin: Double) -> Bool {
        let low = margin, high = 1 - margin
        return red >= low && red <= high
            && green >= low && green <= high
            && blue >= low && blue <= high
    }

    var clamped: RGBComponents {
        RGBComponents(red: min(max(red, 0), 1),
                      green: min(max(green, 0), 1),
                      blue: min(max(blue, 0), 1))
    }

    var hexString: String {
        let c = clamped
        let r = Int((c.red * 255).rounded())
        let g = Int((c.green * 255).rounded())
        let b = Int((c.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension BlendColor {
    /// Oklab -> gamma-encoded sRGB (Björn Ottosson's matrices).
    var rgb: RGBComponents {
        let lp = l + 0.3963377774 * a + 0.2158037573 * b
        let mp = l - 0.1055613458 * a - 0.0638541728 * b
        let sp = l - 0.0894841775 * a - 1.2914855480 * b

        let lc = lp * lp * lp
        let mc = mp * mp * mp
        let sc = sp * sp * sp

        let r =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        return RGBComponents(red: BlendColor.encodeSRGB(r),
                             green: BlendColor.encodeSRGB(g),
                             blue: BlendColor.encodeSRGB(bl))
    }

    /// Gamma-encoded sRGB -> Oklab.
    ///
    /// These constants are the exact double-precision inverses of the matrices
    /// in `rgb` above, rather than Ottosson's separately-rounded published
    /// pair. Published, the two directions only agree to about seven digits,
    /// which leaves a round trip off by ~1e-7; inverting the forward matrices
    /// instead brings it to ~1e-14. The forward direction — the one that puts
    /// colour on screen — is untouched, so nothing the generator produces
    /// moves by a bit.
    init(rgb: RGBComponents) {
        let r = BlendColor.decodeSRGB(rgb.red)
        let g = BlendColor.decodeSRGB(rgb.green)
        let b = BlendColor.decodeSRGB(rgb.blue)

        let lc = 0.4122214708018042 * r + 0.5363325363454300 * g + 0.0514459928527659 * b
        let mc = 0.2119034982505859 * r + 0.6806995451361226 * g + 0.1073969566132915 * b
        let sc = 0.0883024618887421 * r + 0.2817188376235318 * g + 0.6299787004877261 * b

        let lp = cbrt(lc), mp = cbrt(mc), sp = cbrt(sc)

        self.init(l: 0.2104542682745813 * lp + 0.7936177747300267 * mp - 0.0040720430046080 * sp,
                  a: 1.9779985323885081 * lp - 2.4285922419362862 * mp + 0.4505937095477779 * sp,
                  b: 0.0259040424876582 * lp + 0.7827717124269178 * mp - 0.8086757549145760 * sp)
    }

    static func encodeSRGB(_ value: Double) -> Double {
        value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
    }

    static func decodeSRGB(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// True when the colour survives the round trip to the screen intact.
    func isDisplayable(margin: Double = 0.012) -> Bool {
        rgb.isInsideGamut(margin: margin)
    }

    var hexString: String { rgb.hexString }

    /// Pulls the colour back inside sRGB by draining chroma, keeping its
    /// lightness and hue. Used for decorative palettes, never for puzzle
    /// colours — those are generated in gamut so their blends stay exact.
    func clippedToGamut(margin: Double = 0.01) -> BlendColor {
        guard !isDisplayable(margin: margin) else { return self }
        let hue = self.hue
        var low = 0.0
        var high = chroma
        for _ in 0..<20 {
            let mid = (low + high) / 2
            let candidate = BlendColor(lightness: l, chroma: mid, hue: hue)
            if candidate.isDisplayable(margin: margin) { low = mid } else { high = mid }
        }
        return BlendColor(lightness: l, chroma: low, hue: hue)
    }

    /// Spoken description used for VoiceOver and the colour-value overlay.
    var readableName: String {
        let lightness: String
        switch l {
        case ..<0.25: lightness = "very dark"
        case ..<0.45: lightness = "dark"
        case ..<0.62: lightness = "medium"
        case ..<0.80: lightness = "light"
        default: lightness = "very light"
        }

        guard chroma > 0.035 else { return "\(lightness) grey" }

        let names = ["red", "orange", "yellow", "lime", "green", "spring green",
                     "cyan", "azure", "blue", "violet", "magenta", "rose"]
        // Oklab hue 30 lands close to red; offset so the buckets line up.
        let index = Int(((hue - 20 + 360).truncatingRemainder(dividingBy: 360)) / 30) % names.count
        let saturation = chroma > 0.12 ? "vivid " : (chroma > 0.07 ? "" : "muted ")
        return "\(lightness) \(saturation)\(names[index])"
    }
}
