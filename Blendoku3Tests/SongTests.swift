import XCTest
@testable import Blendoku3

/// The song a solved board plays: when its notes fall, where its beat falls,
/// and whether the mixed sound stays clean. All of it is arithmetic, so all of
/// it is checked without a speaker.
final class SongScheduleTests: XCTestCase {
    /// `count` colours climbing evenly in lightness, one to a cell.
    private func ramp(_ count: Int, row: Int = 0) -> [(point: GridPoint, colour: BlendColor)] {
        (0..<count).map { index in
            let t = Double(index) / Double(max(count - 1, 1))
            return (point: GridPoint(index, row),
                    colour: BlendColor(lightness: 0.30 + 0.50 * t, chroma: 0.08, hue: 210))
        }
    }

    private func song(notes: Int, cells: Int) -> SongSchedule {
        SongSchedule(melody: ramp(notes), spectrum: ramp(cells, row: 1))
    }

    // Expected values are worked out independently of the Swift, from
    // interval = 1.703·n^−0.6304 and climb = 0.6528·m^−0.6117.

    func testTheBiggestBoardsSongLandsAtAboutTenSeconds() {
        // Level 100: thirty-three placed tiles on a sixty-cell board.
        let song = song(notes: 33, cells: 60)
        XCTAssertEqual(song.melody.last!.time, 6.0130, accuracy: 0.001)
        XCTAssertEqual(song.climbStart, 6.6130, accuracy: 0.001)
        XCTAssertEqual(song.lastOnset, 9.7603, accuracy: 0.001)
        XCTAssertEqual(song.duration, 11.6603, accuracy: 0.001)
    }

    func testTheSmallestBoardTakesItsTime() {
        // Level 1: two placed tiles on a three-cell board.
        let song = song(notes: 2, cells: 3)
        XCTAssertEqual(song.melody[1].time, 1.1001, accuracy: 0.001)
        XCTAssertEqual(song.lastOnset, 2.3669, accuracy: 0.001)
    }

    func testBiggerBoardsTakeLongerButNeverLinearlyLonger() {
        var previous = 0.0
        for notes in 2...38 {
            let cells = notes * 2
            let length = song(notes: notes, cells: cells).lastOnset
            XCTAssertGreaterThan(length, previous, "\(notes) notes")
            // Linear growth at the small board's pace would give 38 notes
            // forty-odd seconds; the whole point is that it does not.
            XCTAssertLessThan(length, 11, "\(notes) notes")
            previous = length
        }
    }

    func testTheBeatStaysBetweenAHeartbeatAndAWalk() {
        for notes in 2...38 {
            let interval = SongSchedule.melodyInterval(notes: notes)
            let every = SongSchedule.beatEvery(interval: interval)
            let bpm = 60 / (interval * Double(every))
            XCTAssertGreaterThanOrEqual(bpm, 48, "\(notes) notes beat at \(bpm)")
            XCTAssertLessThanOrEqual(bpm, 90, "\(notes) notes beat at \(bpm)")
        }
    }

    func testTheBeatSubdividesAsBoardsGrow() {
        XCTAssertEqual(song(notes: 2, cells: 3).beatEvery, 1)
        XCTAssertEqual(song(notes: 13, cells: 24).beatEvery, 2)
        XCTAssertEqual(song(notes: 33, cells: 60).beatEvery, 4)
    }

    func testBeatsFallOnMelodyNotesAndTheCrest() {
        let song = song(notes: 13, cells: 24)
        let melodyTimes = Set(song.melody.map(\.time))
        for beat in song.beats.dropLast() {
            XCTAssertTrue(melodyTimes.contains(beat.time))
        }
        XCTAssertEqual(song.beats.last?.time, song.lastOnset)
        XCTAssertEqual(song.beats.last?.accent, true)
        XCTAssertEqual(song.beats.first?.accent, true)
    }

    func testTheMelodyKeepsThePlayersOrder() {
        // Placed dark, light, middle: the song must not tidy that up.
        let order = [ramp(3)[0], ramp(3)[2], ramp(3)[1]]
        let song = SongSchedule(melody: order, spectrum: ramp(3, row: 1))
        XCTAssertEqual(song.melody.map(\.point), order.map(\.point))
    }

    func testTheClimbAlwaysRises() {
        var rng = TestRNG(state: 11)
        let shuffled = ramp(40).shuffled(using: &rng)
        let song = SongSchedule(melody: [], spectrum: shuffled)
        let lightness = song.climb.map(\.colour.l)
        XCTAssertEqual(lightness, lightness.sorted())
        let times = song.climb.map(\.time)
        XCTAssertEqual(times, times.sorted())
        XCTAssertEqual(song.climbStart, 0)
    }

    func testEveryCellLightsAndOnlyPlacedCellsHaveANote() {
        let melody = Array(ramp(8).prefix(5))
        let song = SongSchedule(melody: melody, spectrum: ramp(8))
        let pulses = song.pulses()
        XCTAssertEqual(pulses.count, 8)
        XCTAssertEqual(pulses.values.filter { $0.melody != nil }.count, 5)
        XCTAssertTrue(pulses.values.allSatisfy { $0.climb != nil })
        for pulse in pulses.values {
            if let melody = pulse.melody, let climb = pulse.climb {
                XCTAssertLessThan(melody, climb, "a cell's climb must come after its note")
            }
        }
    }

    func testThePlayheadHopsThenSweeps() {
        let song = song(notes: 4, cells: 6)
        XCTAssertNil(song.ribbonPosition(at: -0.1))
        XCTAssertEqual(song.ribbonPosition(at: 0) ?? -1, 0, accuracy: 1e-9)
        var previous = -1.0
        for note in song.climb {
            let position = song.ribbonPosition(at: note.time + 0.001) ?? -1
            XCTAssertGreaterThanOrEqual(position, previous)
            previous = position
        }
        XCTAssertEqual(previous, 1, accuracy: 1e-9)
    }

    func testAKeepsakeRebuildsTheSameSong() {
        let melody = ramp(6).map(\.colour)
        let spectrum = ramp(10).map(\.colour)
        let rebuilt = SongSchedule(melody: melody, spectrum: spectrum)
        let original = SongSchedule(melody: ramp(6), spectrum: ramp(10, row: 1))
        XCTAssertEqual(rebuilt.melody.map(\.time), original.melody.map(\.time))
        XCTAssertEqual(rebuilt.climb.map(\.colour), original.climb.map(\.colour))
        XCTAssertEqual(rebuilt.duration, original.duration, accuracy: 1e-12)
    }

    func testAnEmptySongIsHarmless() {
        let song = SongSchedule(melody: [BlendColor](), spectrum: [BlendColor]())
        XCTAssertEqual(song.duration, 0)
        XCTAssertTrue(song.beats.isEmpty)
        XCTAssertNil(song.ribbonPosition(at: 1))
        XCTAssertTrue(SongComposer.render(song, warmth: 0.5).isEmpty)
        XCTAssertTrue(BeatScore.events(for: song).isEmpty)
    }
}

final class SongComposerTests: XCTestCase {
    private func board(_ level: Int) -> (GameSession, SongSchedule) {
        let session = GameSession(puzzle: Fixtures.allLevels[level - 1])
        session.solveCompletely()
        let song = SongSchedule(puzzle: session.puzzle, order: session.placementOrder) {
            session.colour(at: $0)
        }
        return (session, song)
    }

    func testRealSongsNeverComeNearClipping() {
        for level in [1, 25, 50, 75, 100] {
            let (_, song) = board(level)
            for warmth in [0.0, 1.0] {
                let samples = SongComposer.render(song, warmth: warmth, sampleRate: 22_050)
                let peak = SongComposer.peak(samples)
                // Well under the ceiling: the limiter is a safety net, and if
                // it ever has to act the voice gains have drifted.
                XCTAssertLessThan(peak, 0.6, "level \(level) warmth \(warmth)")
                XCTAssertGreaterThan(peak, 0.05, "level \(level) is silent")
            }
        }
    }

    func testTheWorstCaseMelodyStaysClean() {
        // Thirty-three copies of the same pitch, stacked as tightly as the
        // biggest board plays them: every note reinforcing the last.
        let same = BlendColor(lightness: 0.62, chroma: 0.1, hue: 30)
        let melody = Array(repeating: same, count: 33)
        let spectrum = Array(repeating: BlendColor(lightness: 0.88, chroma: 0.05, hue: 30), count: 60)
        let samples = SongComposer.render(SongSchedule(melody: melody, spectrum: spectrum),
                                          warmth: 1, sampleRate: 22_050)
        XCTAssertLessThanOrEqual(SongComposer.peak(samples), SongComposer.ceiling)
    }

    func testTheBufferCoversTheWholeSongAndStartsSilent() {
        let (_, song) = board(40)
        let rate = 22_050.0
        let samples = SongComposer.render(song, warmth: 0.5, sampleRate: rate)
        XCTAssertGreaterThanOrEqual(Double(samples.count) / rate, song.duration)
        XCTAssertEqual(samples.first ?? 1, 0, accuracy: 1e-6, "a song that starts mid-wave clicks")
    }

    func testRenderingIsDeterministic() {
        let (_, song) = board(12)
        XCTAssertEqual(SongComposer.render(song, warmth: 0.3, sampleRate: 11_025),
                       SongComposer.render(song, warmth: 0.3, sampleRate: 11_025))
    }
}

final class BeatScoreTests: XCTestCase {
    func testTheScoreIsTapsAndOneSwell() {
        let puzzle = Fixtures.allLevels[59]
        let session = GameSession(puzzle: puzzle)
        session.solveCompletely()
        let song = SongSchedule(puzzle: puzzle, order: session.placementOrder) { session.colour(at: $0) }
        let events = BeatScore.events(for: song)

        let taps = events.filter { $0.kind == .tap }
        let swells = events.filter { $0.kind == .swell }
        XCTAssertEqual(taps.count, song.beats.count)
        XCTAssertEqual(swells.count, 1)
        XCTAssertEqual(swells[0].time, song.climbStart, accuracy: 1e-9)
        XCTAssertEqual(swells[0].time + swells[0].duration, song.lastOnset, accuracy: 1e-9)
        XCTAssertLessThan(swells[0].rampFrom, 1, "the swell should rise, not arrive")

        // The crest is the hardest knock in the song.
        let crest = taps.max { $0.intensity < $1.intensity }
        XCTAssertEqual(crest?.time ?? -1, song.lastOnset, accuracy: 1e-9)
    }

    func testEveryValueIsSomethingCoreHapticsAccepts() {
        for level in stride(from: 1, through: 100, by: 9) {
            let puzzle = Fixtures.allLevels[level - 1]
            let session = GameSession(puzzle: puzzle)
            session.solveCompletely()
            let song = SongSchedule(puzzle: puzzle, order: session.placementOrder) { session.colour(at: $0) }
            let events = BeatScore.events(for: song)
            XCTAssertEqual(events.map(\.time), events.map(\.time).sorted())
            for event in events {
                XCTAssertGreaterThanOrEqual(event.time, 0)
                XCTAssertTrue((0...1).contains(event.intensity))
                XCTAssertTrue((0...1).contains(event.sharpness))
                XCTAssertTrue((0...1).contains(event.rampFrom))
                if event.kind == .swell { XCTAssertGreaterThan(event.duration, 0) }
            }
        }
    }
}
