import Foundation

/// One struck tone.
struct ToneSpec: Hashable, Sendable {
    var frequency: Double
    /// A second voice a few hertz away. Two tones that close do not sound like
    /// two notes — they sound like one note wavering, which is what "not quite
    /// right" sounds like.
    var companion: Double?
    var seconds: Double
    /// Time constant of the decay, in seconds.
    var decay: Double
    /// 0 glassy, 1 round. Set by the level, not the tile.
    var warmth: Double
    var gain: Double
}

/// Turning a colour into a pitch.
///
/// The game asks the player to judge one colour against its neighbour, so the
/// sound is built from the same quantity: **lightness picks the note**. A tile
/// that belongs further along a ramp sounds further up the scale, and a correct
/// run played back in order is a rising figure — in tune because being correct
/// is what puts it in tune.
///
/// Hue does *not* move the pitch. It sets the timbre, and it does so once per
/// level rather than per tile: the board chooses the instrument, the tile
/// chooses the note. Letting hue bend the pitch too would make the one thing
/// the ear is supposed to track — where this colour sits — ambiguous.
enum Tuning {

    /// A3. Low enough to be calm, high enough that a phone speaker can
    /// actually reproduce it; anything under about 200 Hz is mostly lost.
    static let root = 220.0

    /// Just-intonation major pentatonic. Every degree is a small-integer ratio
    /// to the root, which is what "harmonic" means literally rather than
    /// approximately — equal temperament is a little out of tune everywhere by
    /// design, and this is a game about noticing small differences.
    ///
    /// Pentatonic because it has no semitones: *no two notes in this scale can
    /// clash*, so a player jabbing at tiles cannot produce a sour chord by
    /// accident. Only a wrong placement is allowed to sound wrong.
    static let degrees = [1.0, 9.0 / 8, 5.0 / 4, 3.0 / 2, 5.0 / 3]

    /// Two and a half octaves: 220 Hz to 1100 Hz.
    static let steps = 13

    /// How far apart the two voices of a wrong placement beat, in hertz.
    ///
    /// Specified as a *beat rate* rather than as an interval in cents, which
    /// was the first thing I tried and is wrong: a fixed 33-cent detune beats
    /// at 4 Hz on a dark tile and 21 Hz on a light one, so the same mistake
    /// would sound like a gentle wobble low down and like roughness up high.
    /// Fixing the beat rate instead makes the feeling identical at every pitch,
    /// and lets the interval shrink from 35 cents to 7 as the note rises.
    ///
    /// 4.5 Hz is about five wobbles inside one note — unmistakable, and slow
    /// enough to stay calm.
    static let beat = 4.5

    /// Where the generator actually puts its lightness. Mapping the full 0...1
    /// would waste most of the scale on colours no board contains.
    static let lightnessRange = 0.26...0.88

    // MARK: - Pitch

    static func step(for colour: BlendColor) -> Int {
        let span = lightnessRange.upperBound - lightnessRange.lowerBound
        let t = (colour.l - lightnessRange.lowerBound) / span
        let index = (t * Double(steps - 1)).rounded()
        return min(max(Int(index), 0), steps - 1)
    }

    static func frequency(at step: Int) -> Double {
        let clamped = min(max(step, 0), steps - 1)
        let octave = clamped / degrees.count
        let degree = clamped % degrees.count
        return root * degrees[degree] * pow(2, Double(octave))
    }

    // MARK: - Timbre

    /// Warm hues ring round and flute-like, cool hues ring glassy. Scaled by
    /// chroma so a near-grey level sits in the middle rather than being thrown
    /// to one extreme by a hue that is barely there.
    static func warmth(forHue hue: Double, chroma: Double) -> Double {
        let radians = (hue - 30) * .pi / 180
        let swing = (1 + cos(radians)) / 2
        let strength = min(1, chroma / 0.12)
        return 0.5 + (swing - 0.5) * strength
    }

    // MARK: - Voices

    enum Event: Hashable, Sendable {
        /// Lifting a tile. Its own note an octave down and barely there.
        case pickUp
        /// Placed where it belongs.
        case settled
        /// Placed somewhere legal, but it is the wrong colour for the slot.
        case unsettled
    }

    /// How many decay time-constants a tone is given before its buffer ends.
    ///
    /// Three takes the envelope down to about 5% — quiet enough that the tail
    /// fade has nothing left to cut. The first pass paired a 1.15s decay with a
    /// 1.6s buffer, which ends the note at a quarter of full volume and leaves
    /// a 50ms ramp to do the rest: audible as a note being *stopped* rather
    /// than ending, which is the opposite of the point.
    static let tail = 3.0

    static func voice(step: Int, event: Event, warmth: Double) -> ToneSpec {
        let note = frequency(at: step)
        switch event {
        case .pickUp:
            return ToneSpec(frequency: note / 2, companion: nil,
                            seconds: 0.60, decay: 0.60 / tail,
                            warmth: warmth, gain: 0.45)
        case .settled:
            return ToneSpec(frequency: note, companion: nil,
                            seconds: 1.90, decay: 1.90 / tail,
                            warmth: warmth, gain: 1.0)
        case .unsettled:
            // Shorter as well as wavering: a note that does not get to ring is
            // already saying something before the beating is audible.
            return ToneSpec(frequency: note, companion: note + beat,
                            seconds: 1.15, decay: 1.15 / tail,
                            warmth: warmth, gain: 0.9)
        }
    }
}
