import Foundation

/// When each note of a finished board's song lands, and where its beat falls.
///
/// A solved board plays back twice over. First **your order**: every tile you
/// placed, in the order it went down, at the pitch its lightness gives it —
/// the tune you wrote without meaning to. Then **the climb**: every cell on
/// the board, darkest to lightest, run up the scale in one breath.
///
/// Pacing is the whole trick. Spacing notes evenly would make a thirty-three
/// tile board take half a minute, and squeezing everything into a fixed length
/// would make a two-tile board a hiccup. So the gap between notes shrinks as a
/// power of the note count, `interval = 1.703 · n^−0.63`, which makes the total
/// length grow only logarithmically. Two tiles take their time and breathe;
/// the hundredth board's whole song — both passes — lands at about ten seconds.
struct SongSchedule: Equatable, Sendable {
    struct Note: Equatable, Sendable {
        var time: Double
        var point: GridPoint
        var colour: BlendColor

        var step: Int { Tuning.step(for: colour) }
    }

    struct Beat: Equatable, Sendable {
        var time: Double
        /// Every fourth beat lands a little harder, so the pulse has a bar to
        /// it rather than being a metronome. The crest is always accented.
        var accent: Bool
    }

    /// When a cell lights during the playback: once for its note in your
    /// order (placed tiles only), and once as the climb passes through it.
    struct Pulse: Equatable, Sendable {
        var melody: Double?
        var climb: Double?
    }

    let melody: [Note]
    let climb: [Note]
    let beats: [Beat]
    /// How many melody notes share one beat.
    let beatEvery: Int
    let climbStart: Double
    /// When the final note starts.
    let lastOnset: Double
    /// When the final note has finished ringing.
    let duration: Double

    // MARK: - Pacing

    static let melodyScale = 1.703
    static let melodyExponent = 0.6304
    static let climbScale = 0.6528
    static let climbExponent = 0.6117
    /// The breath between your order and the climb.
    static let gap = 0.60

    /// The closest two beats may fall: 0.66 s, about 90 BPM.
    static let beatFloor = 0.66
    /// The beat subdivides the melody rather than following it note for note,
    /// taking the fewest notes per beat that keep it at least `beatFloor`
    /// apart. On a small board that is every note; on the largest, every
    /// fourth. Across every board the game makes the pulse stays between
    /// about 49 and 89 BPM — resting heart rate to an easy walk — however
    /// many tiles there were.
    ///
    /// A floor rather than a target on purpose. Aiming for the *nearest*
    /// subdivision to a comfortable tempo lets a five-tile board run at 97,
    /// because that is where the choice flips between every note and every
    /// other one. Calm is the point, so ties go to the slower beat.
    static let subdivisions = [1, 2, 3, 4, 6, 8]

    static func melodyInterval(notes: Int) -> Double {
        melodyScale * pow(Double(max(notes, 1)), -melodyExponent)
    }

    static func climbInterval(cells: Int) -> Double {
        climbScale * pow(Double(max(cells, 1)), -climbExponent)
    }

    static func beatEvery(interval: Double) -> Int {
        guard interval > 0 else { return 1 }
        return subdivisions.first { interval * Double($0) >= beatFloor } ?? subdivisions[subdivisions.count - 1]
    }

    // MARK: - Building

    /// - Parameters:
    ///   - melody: the placed cells, in the order they were placed.
    ///   - spectrum: every cell on the board, in any order. The climb sorts
    ///     it by lightness itself, so no caller can hand it a climb that
    ///     doubles back.
    init(melody: [(point: GridPoint, colour: BlendColor)],
         spectrum: [(point: GridPoint, colour: BlendColor)]) {
        let noteGap = Self.melodyInterval(notes: melody.count)
        let placed = melody.enumerated().map { index, entry in
            Note(time: Double(index) * noteGap, point: entry.point, colour: entry.colour)
        }

        let start = placed.last.map { $0.time + Self.gap } ?? 0
        let risingGap = Self.climbInterval(cells: spectrum.count)
        let rising = spectrum.enumerated()
            .sorted { lhs, rhs in
                lhs.element.colour.l == rhs.element.colour.l
                    ? lhs.offset < rhs.offset
                    : lhs.element.colour.l < rhs.element.colour.l
            }
            .enumerated()
            .map { index, entry in
                Note(time: start + Double(index) * risingGap,
                     point: entry.element.point, colour: entry.element.colour)
            }

        let every = placed.isEmpty ? 1 : Self.beatEvery(interval: noteGap)
        var beats: [Beat] = []
        for (index, note) in placed.enumerated() where index % every == 0 {
            beats.append(Beat(time: note.time, accent: beats.count % 4 == 0))
        }
        if let crest = rising.last {
            beats.append(Beat(time: crest.time, accent: true))
        }

        let last = rising.last ?? placed.last
        let ring = rising.isEmpty
            ? Tuning.voice(step: 0, event: .replay, warmth: 0).seconds
            : Tuning.voice(step: 0, event: .crest, warmth: 0).seconds

        self.melody = placed
        self.climb = rising
        self.beats = beats
        self.beatEvery = every
        self.climbStart = start
        self.lastOnset = last?.time ?? 0
        self.duration = (last?.time ?? 0) + (last == nil ? 0 : ring)
    }

    /// Where along a lightness-sorted ribbon the song is `seconds` in, from
    /// 0 at its darkest colour to 1 at its lightest; nil before the first
    /// note. During your order this hops between the notes as they sound;
    /// during the climb it sweeps from one end to the other.
    func ribbonPosition(at seconds: Double) -> Double? {
        let sounding = climb.last(where: { $0.time <= seconds })
            ?? melody.last(where: { $0.time <= seconds })
        guard let sounding else { return nil }
        let range = climb.isEmpty ? melody.map(\.colour.l) : climb.map(\.colour.l)
        guard let low = range.min(), let high = range.max(), high > low else { return 0.5 }
        return min(max((sounding.colour.l - low) / (high - low), 0), 1)
    }

    /// Every cell's moments in the light, keyed by where it sits.
    func pulses() -> [GridPoint: Pulse] {
        var pulses: [GridPoint: Pulse] = [:]
        for note in melody { pulses[note.point, default: Pulse()].melody = note.time }
        for note in climb { pulses[note.point, default: Pulse()].climb = note.time }
        return pulses
    }
}

extension SongSchedule {
    /// The song a solved board makes.
    ///
    /// `order` is the placed cells in the order they went down; any that no
    /// longer show a colour are skipped rather than trusted.
    init(puzzle: Puzzle, order: [GridPoint], colour: (GridPoint) -> BlendColor?) {
        let melody = order.compactMap { point in colour(point).map { (point: point, colour: $0) } }
        let spectrum = puzzle.cells.compactMap { point in
            colour(point).map { (point: point, colour: $0) }
        }
        self.init(melody: melody, spectrum: spectrum)
    }

    /// A song rebuilt from a keepsake, which stores colours but not where
    /// they sat. The points are stand-ins; nothing draws them.
    init(melody: [BlendColor], spectrum: [BlendColor]) {
        self.init(melody: melody.enumerated().map { (point: GridPoint($0.offset, 0), colour: $0.element) },
                  spectrum: spectrum.enumerated().map { (point: GridPoint($0.offset, 1), colour: $0.element) })
    }
}

/// The song's beat, written out as the haptic events that will play it.
///
/// Kept apart from Core Haptics so it can be reasoned about and tested as
/// plain numbers: the phone only ever plays exactly this list.
enum BeatScore {
    struct Event: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// One soft knock.
            case tap
            /// A continuous hum that grows from `rampFrom × intensity` to
            /// `intensity` over its duration.
            case swell
        }

        var kind: Kind
        var time: Double
        var duration: Double = 0
        var intensity: Double
        var sharpness: Double
        var rampFrom: Double = 1
    }

    /// Knocks for the beat, a hum that rises under the climb, and one firm
    /// landing on the crest.
    ///
    /// Low sharpness throughout: sharp haptics read as clicks, and this is
    /// meant to be felt as a pulse, like a hand on a drum.
    static func events(for schedule: SongSchedule) -> [Event] {
        var events: [Event] = []
        let crestTime = schedule.climb.last?.time

        for beat in schedule.beats {
            if let crestTime, beat.time == crestTime {
                events.append(Event(kind: .tap, time: beat.time, intensity: 1.0, sharpness: 0.40))
            } else {
                events.append(Event(kind: .tap, time: beat.time,
                                    intensity: beat.accent ? 0.75 : 0.45,
                                    sharpness: beat.accent ? 0.30 : 0.20))
            }
        }

        let climbLength = schedule.lastOnset - schedule.climbStart
        if schedule.climb.count > 1, climbLength > 0.05 {
            events.append(Event(kind: .swell, time: schedule.climbStart, duration: climbLength,
                                intensity: 0.55, sharpness: 0.30, rampFrom: 0.15))
        }
        return events.sorted { $0.time < $1.time }
    }
}
