import Foundation

/// An affine colour field over the grid: `origin + x·dx + y·dy` in Oklab.
///
/// Affine is the whole trick. Any straight line through an affine field is an
/// arithmetic progression, so every row and every column of a shape is
/// automatically a perfect blend — no per-line bookkeeping required.
struct ColorField: Sendable {
    var origin: BlendColor
    var dx: BlendColor
    var dy: BlendColor

    func colour(at point: GridPoint) -> BlendColor {
        origin + dx * Double(point.x) + dy * Double(point.y)
    }
}

enum ColorFieldFactory {
    /// How far a gradient may travel along lightness across one shape.
    private static let lightnessBudget = 0.74
    /// And how far it may travel through the a/b (colour) plane, which is a
    /// much smaller room than lightness.
    private static let planarBudget = 0.38
    /// Ceiling on any single step, so one shape cannot eat the whole range.
    private static let stepBudget = 0.80

    /// Samples a colour field for one shape.
    ///
    /// The awkward part is the sRGB gamut: it is a squashed, lopsided solid in
    /// Oklab, so a direction picked at random usually walks straight out of it.
    /// Rather than guess and reject, this spends an explicit travel budget —
    /// so much lightness, so much colour — builds a direction that fits inside
    /// it, and then *solves* for how much chroma the ramp can carry. That is
    /// why early levels come out as saturated as the display allows and the
    /// quiet chapters stay quiet.
    static func make(points: [GridPoint],
                     profile: DifficultyProfile,
                     hueOffset: Double,
                     avoid: [BlendColor] = [],
                     rng: inout SplitMix64,
                     attempts: Int = 320) -> ColorField? {
        guard let bounds = GridBounds(points: points) else { return nil }
        let spanX = bounds.width - 1
        let spanY = bounds.height - 1
        let usesX = spanX > 0
        let usesY = spanY > 0
        let separation = profile.minStep * 0.78

        for attempt in 0..<attempts {
            // Loosen a little if the palette is proving hard to place.
            let slack = Double(attempt) / Double(attempts)
            let low = profile.minStep * (1 - 0.10 * slack)
            let high = profile.maxStep * (1 + 0.18 * slack)
            // A long shape has to take smaller steps or it runs off the gamut.
            let highX = usesX ? max(low, min(high, stepBudget / Double(spanX))) : high
            let highY = usesY ? max(low, min(high, stepBudget / Double(spanY))) : high

            let hueCentre = profile.baseHue + hueOffset + rng.nextDouble(in: -12...12)
            let stepX = rng.nextDouble(in: low...highX)
            let stepY = rng.nextDouble(in: low...highY)
            let travelX = usesX ? stepX * Double(spanX) : 0
            let travelY = usesY ? stepY * Double(spanY) : 0

            // Divide the colour-plane budget between the two axes, then give
            // each axis whatever is left over as lightness.
            let planarX = rng.nextDouble(in: 0...(travelX > 0 ? min(1, planarBudget / travelX) : 1))
            let remaining = max(0, planarBudget - travelX * planarX)
            let planarY = rng.nextDouble(in: 0...(travelY > 0 ? min(1, remaining / travelY) : 1))

            let liftX = (1 - planarX * planarX).squareRoot() * (rng.nextBool(probability: 0.5) ? 1 : -1)
            let magnitudeY = (1 - planarY * planarY).squareRoot()
            let freeSign = rng.nextBool(probability: 0.5) ? 1.0 : -1.0
            // If both axes climb the same way they run off the top of the
            // lightness range, so make the second one descend instead.
            let liftY = travelX * abs(liftX) + travelY * magnitudeY > lightnessBudget
                ? -magnitudeY * (liftX < 0 ? -1 : 1)
                : magnitudeY * freeSign

            let thetaX = (hueCentre + rng.nextDouble(in: -profile.hueSpread...profile.hueSpread)) * .pi / 180
            let thetaY = (hueCentre + rng.nextDouble(in: -profile.hueSpread...profile.hueSpread)) * .pi / 180

            var dx = BlendColor(l: 0, a: 0, b: 0)
            var dy = BlendColor(l: 0, a: 0, b: 0)
            if usesX {
                dx = BlendColor(l: liftX, a: planarX * cos(thetaX), b: planarX * sin(thetaX)) * stepX
            }
            if usesY {
                dy = BlendColor(l: liftY, a: planarY * cos(thetaY), b: planarY * sin(thetaY)) * stepY
            }

            // Two axes that point the same way turn a grid into a mush of
            // near-duplicates, so insist they are properly oblique.
            if usesX && usesY {
                let cosine = abs(dot(dx, dy) / (dx.magnitude * dy.magnitude))
                if cosine > 0.90 { continue }
            }

            let offsets = points.map { point in
                dx * (Double(point.x) - Double(spanX) / 2) + dy * (Double(point.y) - Double(spanY) / 2)
            }
            let lowestOffset = offsets.map(\.l).min() ?? 0
            let highestOffset = offsets.map(\.l).max() ?? 0

            // Place the ramp's lightness so both ends stay on screen.
            let lowestL = max(profile.lightnessRange.lowerBound, 0.135 - lowestOffset)
            let highestL = min(profile.lightnessRange.upperBound, 0.925 - highestOffset)
            guard lowestL <= highestL else { continue }

            let centreL = rng.nextDouble(in: lowestL...highestL)
            let fraction = rng.nextDouble(in: profile.chromaFraction)

            // Contract the gradient until the whole field fits, giving up as
            // soon as the steps would become imperceptible.
            var factor = 1.0
            for _ in 0..<10 {
                let scaledX = dx * factor
                let scaledY = dy * factor
                if usesX && scaledX.magnitude < profile.minStep * 0.995 { break }
                if usesY && scaledY.magnitude < profile.minStep * 0.995 { break }

                let scaled = offsets.map { $0 * factor }
                let headroom = maxFeasibleChroma(centreL: centreL, hue: hueCentre,
                                                 offsets: scaled, ceiling: profile.maxCellChroma)
                if headroom >= 0.010 {
                    let centre = BlendColor(lightness: centreL, chroma: headroom * fraction, hue: hueCentre)
                    let origin = centre
                        - scaledX * (Double(spanX) / 2)
                        - scaledY * (Double(spanY) / 2)
                    let field = ColorField(origin: origin, dx: scaledX, dy: scaledY)
                    let colours = points.map { field.colour(at: $0) }

                    let clearOfBoard = avoid.isEmpty || colours.allSatisfy { colour in
                        avoid.allSatisfy { $0.distance(to: colour) >= separation }
                    }
                    if clearOfBoard,
                       colours.allSatisfy({ fits($0, ceiling: profile.maxCellChroma) }),
                       minimumPairDistance(colours) >= separation {
                        return field
                    }
                }
                factor *= 0.92
            }
        }
        return nil
    }

    /// Largest chroma the ramp's centre can carry with every cell still on
    /// screen. Moving the centre away from grey pushes every cell outwards, so
    /// the predicate is monotone enough to bisect — and the caller re-checks
    /// the result anyway.
    private static func maxFeasibleChroma(centreL: Double, hue: Double,
                                          offsets: [BlendColor], ceiling: Double) -> Double {
        func feasible(_ chroma: Double) -> Bool {
            let centre = BlendColor(lightness: centreL, chroma: chroma, hue: hue)
            return offsets.allSatisfy { fits(centre + $0, ceiling: ceiling) }
        }
        guard feasible(0) else { return -1 }

        var low = 0.0
        var high = 0.40
        for _ in 0..<18 {
            let mid = (low + high) / 2
            if feasible(mid) { low = mid } else { high = mid }
        }
        return low
    }

    private static func fits(_ colour: BlendColor, ceiling: Double) -> Bool {
        colour.isDisplayable(margin: 0.018)
            && colour.l > 0.12 && colour.l < 0.94
            && colour.chroma <= ceiling
    }

    private static func dot(_ lhs: BlendColor, _ rhs: BlendColor) -> Double {
        lhs.l * rhs.l + lhs.a * rhs.a + lhs.b * rhs.b
    }

    static func minimumPairDistance(_ colours: [BlendColor]) -> Double {
        guard colours.count > 1 else { return .infinity }
        var smallest = Double.infinity
        for i in 0..<(colours.count - 1) {
            for j in (i + 1)..<colours.count {
                smallest = min(smallest, colours[i].distance(to: colours[j]))
            }
        }
        return smallest
    }
}
