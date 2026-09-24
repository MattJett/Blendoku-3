import XCTest
@testable import Blendoku3

/// Plays the whole first arc, silently: every one of the hundred boards solved
/// the way a person would — one tile at a time, in no particular order, with
/// the odd wrong placement on the way — and every consequence checked. The
/// record it earns, the level it unlocks, the song it makes and the beat that
/// song carries.
///
/// No sound is made and nothing vibrates: the host app knows it is under test
/// and keeps quiet, and everything checked here is the arithmetic the sound
/// and the haptics are built from.
final class PlaythroughTests: XCTestCase {
    func testEveryBoardInTheArcCanBePlayedToTheEnd() {
        var rng = TestRNG(state: 100)
        let progress = ProgressStore(directory: Fixtures.scratchDirectory())

        for puzzle in Fixtures.allLevels {
            let level = puzzle.level
            XCTAssertTrue(progress.isUnlocked(level), "level \(level) locked on arrival")

            let clock = Fixtures.Clock()
            let session = GameSession(puzzle: puzzle) { clock.now }

            // One deliberate mistake first, where the board allows one.
            let slots = puzzle.slots.shuffled(using: &rng)
            if slots.count >= 2,
               let wrong = puzzle.solutionTile(for: slots[1]) {
                XCTAssertTrue(session.place(wrong, at: slots[0]), "level \(level)")
                XCTAssertFalse(session.isCorrect(at: slots[0]))
            }

            // Then every tile to its home, in a shuffled order.
            for slot in slots {
                guard let tile = puzzle.solutionTile(for: slot) else {
                    return XCTFail("level \(level) has a slot with no tile")
                }
                session.place(tile, at: slot)
                clock.advance(2)
            }

            XCTAssertTrue(session.isSolved, "level \(level) did not solve")
            XCTAssertEqual(session.remainingCount, 0)
            XCTAssertTrue(puzzle.slots.allSatisfy { session.isCorrect(at: $0) }, "level \(level)")

            progress.complete(level: level, moves: session.moves, seconds: session.elapsed,
                              hintsUsed: session.hintsUsed, perfectMoves: puzzle.slots.count)
            XCTAssertNotNil(progress.record(for: level))

            // The song.
            let song = SongSchedule(puzzle: puzzle, order: session.placementOrder) {
                session.colour(at: $0)
            }
            XCTAssertEqual(song.melody.count, puzzle.slots.count, "level \(level)")
            XCTAssertEqual(song.climb.count, puzzle.cells.count, "level \(level)")
            XCTAssertLessThan(song.lastOnset, 10.5, "level \(level)'s song runs long")
            XCTAssertGreaterThan(song.lastOnset, 1, "level \(level)'s song is a blip")

            let every = song.beatEvery
            let bpm = 60 / (SongSchedule.melodyInterval(notes: song.melody.count) * Double(every))
            XCTAssertTrue((48...90).contains(bpm), "level \(level) beats at \(bpm) BPM")

            // The order the song plays is the order the tiles last went down.
            let order = session.placementOrder
            XCTAssertEqual(Set(order), Set(puzzle.slots))
            XCTAssertEqual(order.last, slots.last, "level \(level): the final tile placed is the final note")
        }

        XCTAssertEqual(progress.completedCount, DifficultyCurve.levelCount)
        XCTAssertTrue(progress.isArcComplete)
        XCTAssertEqual(Chromarc.standings { progress.completed(in: $0) }[1], .done)
    }

    func testHintsAloneCanFinishEveryTenthBoard() {
        for puzzle in Fixtures.allLevels where puzzle.level % 10 == 1 || puzzle.level == 100 {
            let session = GameSession(puzzle: puzzle)
            var guardrail = 0
            while !session.isSolved && guardrail < 200 {
                XCTAssertNotNil(session.revealHint(), "level \(puzzle.level) ran out of hints")
                guardrail += 1
            }
            XCTAssertTrue(session.isSolved, "level \(puzzle.level)")
            XCTAssertEqual(session.hintsUsed, puzzle.slots.count)
        }
    }
}
