import XCTest
@testable import Blendoku3

final class ColorMathTests: XCTestCase {
    /// Sweeps the cube rather than picking a few colours, because the failure
    /// this guards against — the two conversion matrices drifting out of being
    /// each other's inverse — shows up as a small error everywhere at once.
    func testSRGBRoundTripIsExact() {
        let steps = stride(from: 0.0, through: 1.0, by: 0.2)
        var worst = 0.0
        for red in steps {
            for green in steps {
                for blue in steps {
                    let sample = RGBComponents(red: red, green: green, blue: blue)
                    let round = BlendColor(rgb: sample).rgb
                    worst = max(worst, abs(round.red - sample.red))
                    worst = max(worst, abs(round.green - sample.green))
                    worst = max(worst, abs(round.blue - sample.blue))
                }
            }
        }
        XCTAssertLessThan(worst, 1e-12, "sRGB round trip drifted by \(worst)")
    }

    func testMidpointOfTwoColoursIsTheirAverage() {
        let start = BlendColor(lightness: 0.3, chroma: 0.08, hue: 40)
        let end = BlendColor(lightness: 0.8, chroma: 0.05, hue: 210)
        let middle = BlendColor.mix(start, end, 0.5)
        XCTAssertEqual(middle.l, (start.l + end.l) / 2, accuracy: 1e-12)
        XCTAssertEqual(middle.a, (start.a + end.a) / 2, accuracy: 1e-12)
        XCTAssertEqual(middle.b, (start.b + end.b) / 2, accuracy: 1e-12)
    }

    func testChromaAndHueRoundTrip() {
        let colour = BlendColor(lightness: 0.6, chroma: 0.12, hue: 137)
        XCTAssertEqual(colour.chroma, 0.12, accuracy: 1e-12)
        XCTAssertEqual(colour.hue, 137, accuracy: 1e-9)
    }

    func testGamutDetection() {
        XCTAssertTrue(BlendColor(lightness: 0.5, chroma: 0.0, hue: 0).isDisplayable())
        // No display can show a mid-grey lightness with that much colour.
        XCTAssertFalse(BlendColor(lightness: 0.5, chroma: 0.45, hue: 120).isDisplayable())
    }

    func testClippingBringsColoursBackIntoGamut() {
        let wild = BlendColor(lightness: 0.45, chroma: 0.5, hue: 150)
        let clipped = wild.clippedToGamut()
        XCTAssertTrue(clipped.isDisplayable(margin: 0.005))
        XCTAssertEqual(clipped.l, wild.l, accuracy: 1e-12)
        XCTAssertLessThan(clipped.chroma, wild.chroma)
    }

    func testReadableNamesDescribeTheColour() {
        XCTAssertTrue(BlendColor(lightness: 0.15, chroma: 0.01, hue: 0).readableName.contains("grey"))
        XCTAssertTrue(BlendColor(lightness: 0.9, chroma: 0.005, hue: 0).readableName.contains("very light"))
    }
}
