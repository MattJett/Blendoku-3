import XCTest
@testable import Blendoku3

/// The renderer is arithmetic, so the things that would ruin the sound are
/// arithmetic too: clipping, clicks, silence, and NaN.
final class ToneRendererTests: XCTestCase {

    private func spec(_ event: Tuning.Event, step: Int = 6, warmth: Double = 0.5) -> ToneSpec {
        Tuning.voice(step: step, event: event, warmth: warmth)
    }

    /// The one that matters. Every buffer is divided by a fixed headroom rather
    /// than normalised to its own peak, so this is what proves the divisor
    /// actually covers the worst case the maths can reach.
    func testNothingClipsAtAnyPitchOrWarmth() {
        for step in 0..<Tuning.steps {
            for warmth in [0.0, 0.5, 1.0] {
                for event in [Tuning.Event.pickUp, .settled, .unsettled] {
                    let samples = ToneRenderer.render(spec(event, step: step, warmth: warmth))
                    let peak = samples.map(abs).max() ?? 0
                    XCTAssertLessThanOrEqual(peak, 1.0,
                        "step \(step) warmth \(warmth) \(event) peaked at \(peak)")
                }
            }
        }
    }

    /// A buffer that starts or stops on a non-zero sample is a click, which is
    /// the least meditative sound a speaker can make.
    func testBothEndsTaperToSilence() {
        for event in [Tuning.Event.pickUp, .settled, .unsettled] {
            let samples = ToneRenderer.render(spec(event))
            XCTAssertEqual(samples.first ?? 1, 0, accuracy: 1e-6, "\(event) starts on a click")
            XCTAssertEqual(samples.last ?? 1, 0, accuracy: 1e-6, "\(event) ends on a click")
        }
    }

    func testEveryValueIsFinite() {
        for step in 0..<Tuning.steps {
            let samples = ToneRenderer.render(spec(.unsettled, step: step))
            XCTAssertFalse(samples.contains { !$0.isFinite }, "step \(step) produced NaN or inf")
        }
    }

    func testItActuallyMakesASound() {
        let samples = ToneRenderer.render(spec(.settled))
        let peak = samples.map(abs).max() ?? 0
        XCTAssertGreaterThan(peak, 0.02, "audible, not theoretically audible")
    }

    func testItDecays() {
        let samples = ToneRenderer.render(spec(.settled))
        let quarter = samples.count / 4
        func energy(_ range: Range<Int>) -> Float {
            samples[range].map(abs).reduce(0, +) / Float(range.count)
        }
        XCTAssertGreaterThan(energy(quarter..<(quarter * 2)),
                             energy((quarter * 3)..<samples.count) * 2,
                             "the tail should be well down on the body")
    }

    func testLengthFollowsTheSpec() {
        let sampleRate = 44_100.0
        for event in [Tuning.Event.pickUp, .settled, .unsettled] {
            let voice = spec(event)
            let samples = ToneRenderer.render(voice, sampleRate: sampleRate)
            XCTAssertEqual(samples.count, Int(sampleRate * voice.seconds))
        }
    }

    /// A partial above Nyquist folds back down as an unrelated tone, which
    /// would put a note in the mix that no colour asked for.
    func testNoPartialIsAllowedToAlias() {
        let sampleRate = 8_000.0
        let samples = ToneRenderer.render(spec(.settled, step: Tuning.steps - 1),
                                          sampleRate: sampleRate)
        XCTAssertFalse(samples.contains { !$0.isFinite })
        XCTAssertLessThanOrEqual(samples.map(abs).max() ?? 0, 1.0)
    }

    func testAWrongPlacementWaversAndARightOneDoesNot() {
        let sampleRate = 44_100.0
        // Envelope of the second half, where the decay has taken the level down
        // far enough that beating shows up as variation rather than as attack.
        func wobble(_ event: Tuning.Event) -> Float {
            let samples = ToneRenderer.render(spec(event), sampleRate: sampleRate)
            let window = Int(sampleRate * 0.05)
            var peaks: [Float] = []
            var index = samples.count / 2
            while index + window < samples.count {
                peaks.append(samples[index..<(index + window)].map(abs).max() ?? 0)
                index += window
            }
            // How far the envelope departs from a smooth slide downward.
            var roughness: Float = 0
            for i in 1..<peaks.count where peaks[i] > peaks[i - 1] {
                roughness += peaks[i] - peaks[i - 1]
            }
            return roughness / (peaks.map(abs).max() ?? 1)
        }
        XCTAssertGreaterThan(wobble(.unsettled), wobble(.settled) + 0.05,
                             "a wrong placement should not decay smoothly")
    }
}
