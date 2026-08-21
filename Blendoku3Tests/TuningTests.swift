import XCTest
@testable import Blendoku3

/// The sound is a claim about the colour, so it gets tested like one.
final class TuningTests: XCTestCase {

    private func colour(lightness: Double) -> BlendColor {
        BlendColor(lightness: lightness, chroma: 0.08, hue: 40)
    }

    // MARK: - Pitch

    func testLighterIsNeverLower() {
        var previous = -1
        for lightness in stride(from: 0.0, through: 1.0, by: 0.01) {
            let step = Tuning.step(for: colour(lightness: lightness))
            XCTAssertGreaterThanOrEqual(step, previous, "lightness \(lightness) went down")
            previous = step
        }
    }

    func testTheWholeScaleIsReachableWithinTheRangeBoardsActuallyUse() {
        let low = Tuning.step(for: colour(lightness: Tuning.lightnessRange.lowerBound))
        let high = Tuning.step(for: colour(lightness: Tuning.lightnessRange.upperBound))
        XCTAssertEqual(low, 0)
        XCTAssertEqual(high, Tuning.steps - 1)
    }

    func testLightnessOutsideTheRangeClampsRatherThanEscaping() {
        XCTAssertEqual(Tuning.step(for: colour(lightness: -5)), 0)
        XCTAssertEqual(Tuning.step(for: colour(lightness: 5)), Tuning.steps - 1)
        XCTAssertEqual(Tuning.frequency(at: -3), Tuning.frequency(at: 0))
        XCTAssertEqual(Tuning.frequency(at: 999), Tuning.frequency(at: Tuning.steps - 1))
    }

    /// Every note is a small-integer ratio to the root — that is what makes
    /// this harmonic in the literal sense rather than the approximate one.
    func testEveryNoteIsAJustRatioToTheRoot() {
        for step in 0..<Tuning.steps {
            let ratio = Tuning.frequency(at: step) / Tuning.root
            let folded = ratio / pow(2, (log2(ratio)).rounded(.down))
            let nearest = Tuning.degrees.min {
                abs($0 - folded) < abs($1 - folded)
            }!
            XCTAssertEqual(folded, nearest, accuracy: 1e-9, "step \(step)")
        }
    }

    /// Pentatonic has no semitones, so no two notes a player can produce by
    /// jabbing at tiles are close enough to clash. Only a wrong placement is
    /// allowed to sound wrong.
    func testNoTwoNotesInTheScaleAreLessThanAWholeToneApart() {
        for step in 1..<Tuning.steps {
            let cents = 1200 * log2(Tuning.frequency(at: step) / Tuning.frequency(at: step - 1))
            XCTAssertGreaterThan(cents, 150, "step \(step) is a semitone or less")
        }
    }

    func testPitchStaysWhereAPhoneCanReproduceIt() {
        for step in 0..<Tuning.steps {
            let frequency = Tuning.frequency(at: step)
            XCTAssertGreaterThanOrEqual(frequency, 200)
            XCTAssertLessThanOrEqual(frequency, 1400)
        }
    }

    // MARK: - Right and wrong

    /// The point of specifying a beat rate rather than an interval: the same
    /// mistake has to feel the same everywhere. A fixed detune in cents beats
    /// nearly five times faster at the top of the scale than the bottom.
    func testAWrongPlacementWaversAtTheSameRateAtEveryPitch() {
        for step in 0..<Tuning.steps {
            let spec = Tuning.voice(step: step, event: .unsettled, warmth: 0.5)
            guard let companion = spec.companion else {
                XCTFail("step \(step) has no second voice to beat against")
                continue
            }
            XCTAssertEqual(companion - spec.frequency, Tuning.beat, accuracy: 1e-9,
                           "step \(step)")
        }
    }

    func testARightPlacementHasNothingToBeatAgainst() {
        for step in 0..<Tuning.steps {
            XCTAssertNil(Tuning.voice(step: step, event: .settled, warmth: 0.5).companion)
            XCTAssertNil(Tuning.voice(step: step, event: .pickUp, warmth: 0.5).companion)
        }
    }

    /// Guards the thing that was wrong the first time round: a decay slower
    /// than its buffer leaves the note still sounding when the samples run out,
    /// so the 50ms tail fade has to chop it off. That reads as a note being
    /// stopped rather than ending.
    func testNoToneIsCutOffBeforeItHasDecayed() {
        for step in 0..<Tuning.steps {
            for event in [Tuning.Event.pickUp, .settled, .unsettled] {
                let spec = Tuning.voice(step: step, event: event, warmth: 0.5)
                XCTAssertEqual(spec.seconds / spec.decay, Tuning.tail, accuracy: 1e-9,
                               "\(event) at step \(step)")
                let remaining = exp(-spec.seconds / spec.decay)
                XCTAssertLessThan(remaining, 0.06,
                                  "\(event) is still at \(remaining) when its buffer ends")
            }
        }
    }

    func testARightPlacementRingsLongerThanAWrongOne() {
        let settled = Tuning.voice(step: 6, event: .settled, warmth: 0.5)
        let unsettled = Tuning.voice(step: 6, event: .unsettled, warmth: 0.5)
        XCTAssertGreaterThan(settled.decay, unsettled.decay)
        XCTAssertGreaterThan(settled.seconds, unsettled.seconds)
    }

    func testPickingUpSoundsAnOctaveBelowPlacing() {
        for step in 0..<Tuning.steps {
            let lift = Tuning.voice(step: step, event: .pickUp, warmth: 0.5)
            let place = Tuning.voice(step: step, event: .settled, warmth: 0.5)
            XCTAssertEqual(lift.frequency * 2, place.frequency, accuracy: 1e-9)
            XCTAssertLessThan(lift.gain, place.gain, "lifting should be quieter than landing")
        }
    }

    // MARK: - Timbre

    func testWarmthIsBoundedAndCentredWhenThereIsNoColourToSpeakOf() {
        for hue in stride(from: 0.0, to: 360.0, by: 7.0) {
            for chroma in [0.0, 0.03, 0.09, 0.30] {
                let warmth = Tuning.warmth(forHue: hue, chroma: chroma)
                XCTAssertGreaterThanOrEqual(warmth, 0)
                XCTAssertLessThanOrEqual(warmth, 1)
            }
            // A grey level has no hue worth hearing, so it must not be thrown
            // to one extreme by whatever the hue nominally is.
            XCTAssertEqual(Tuning.warmth(forHue: hue, chroma: 0), 0.5, accuracy: 1e-9)
        }
    }

    func testWarmHuesRingRounderThanCoolOnes() {
        XCTAssertGreaterThan(Tuning.warmth(forHue: 30, chroma: 0.2),
                             Tuning.warmth(forHue: 210, chroma: 0.2))
    }
}
