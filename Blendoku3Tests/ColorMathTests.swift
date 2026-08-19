import XCTest
@testable import Blendoku3

final class ColorMathTests: XCTestCase {
    func testSRGBRoundTripIsExact() {
        let samples: [RGBComponents] = [
            RGBComponents(red: 0, green: 0, blue: 0),
            RGBComponents(red: 1, green: 1, blue: 1),
            RGBComponents(red: 0.2, green: 0.6, blue: 0.9),
            RGBComponents(red: 0.85, green: 0.13, blue: 0.42),
            RGBComponents(red: 0.5, green: 0.5, blue: 0.5),
        ]
        for sample in samples {
            let round = BlendColor(rgb: sample).rgb
            XCTAssertEqual(round.red, sample.red, accuracy: 1e-9)
            XCTAssertEqual(round.green, sample.green, accuracy: 1e-9)
            XCTAssertEqual(round.blue, sample.blue, accuracy: 1e-9)
        }
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
