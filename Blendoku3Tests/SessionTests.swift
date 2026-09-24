import XCTest
@testable import Blendoku3

/// The parts of a session added for the song, the pause menu and resuming a
/// board: placement order, the clock, the saved snapshot, and the lookup
/// index that now answers "what is in this cell".
final class PlacementOrderTests: XCTestCase {
    private func session(_ level: Int = 30) -> GameSession {
        GameSession(puzzle: Fixtures.allLevels[level - 1])
    }

    func testOrderIsTheOrderTilesWentDown() throws {
        let session = session()
        let slots = Array(session.puzzle.slots.prefix(3))
        try XCTSkipUnless(slots.count == 3)
        for slot in slots.reversed() {
            session.place(session.puzzle.solutionTile(for: slot)!, at: slot)
        }
        XCTAssertEqual(session.placementOrder, slots.reversed())
    }

    func testMovingATileAgainMovesItToTheEndOfTheSong() throws {
        let session = session()
        let slots = Array(session.puzzle.slots.prefix(2))
        try XCTSkipUnless(slots.count == 2)
        let first = session.puzzle.solutionTile(for: slots[0])!
        let second = session.puzzle.solutionTile(for: slots[1])!
        session.place(first, at: slots[0])
        session.place(second, at: slots[1])
        session.returnToTray(first)
        session.place(first, at: slots[0])
        XCTAssertEqual(session.placementOrder, [slots[1], slots[0]])
    }

    func testASwapPlaysTheMovedTileFirst() throws {
        let session = session()
        let slots = Array(session.puzzle.slots.prefix(2))
        try XCTSkipUnless(slots.count == 2)
        let a = session.puzzle.solutionTile(for: slots[0])!
        let b = session.puzzle.solutionTile(for: slots[1])!
        session.place(a, at: slots[0])
        session.place(b, at: slots[1])
        // A onto B's slot: A moved, B was pushed. A is heard first.
        session.place(a, at: slots[1])
        XCTAssertEqual(session.placementOrder, [slots[1], slots[0]])
        XCTAssertEqual(session.tile(at: slots[1]), a)
        XCTAssertEqual(session.tile(at: slots[0]), b)
    }

    func testAnEmptiedSlotLeavesTheSong() throws {
        let session = session()
        let slot = session.puzzle.slots[0]
        let tile = session.puzzle.solutionTile(for: slot)!
        session.place(tile, at: slot)
        session.returnToTray(tile)
        XCTAssertTrue(session.placementOrder.isEmpty)
    }

    func testASolvedBoardsSongHasEveryPlacedTileOnceAndEveryCellInTheClimb() {
        let session = session(64)
        session.solveCompletely()
        XCTAssertTrue(session.isSolved)
        let song = SongSchedule(puzzle: session.puzzle, order: session.placementOrder) {
            session.colour(at: $0)
        }
        XCTAssertEqual(song.melody.count, session.puzzle.slots.count)
        XCTAssertEqual(Set(song.melody.map(\.point)), Set(session.puzzle.slots))
        XCTAssertEqual(song.climb.count, session.puzzle.cells.count)
    }
}

final class SessionClockTests: XCTestCase {
    private func session(_ clock: Fixtures.Clock) -> GameSession {
        GameSession(puzzle: Fixtures.allLevels[9]) { clock.now }
    }

    func testTheClockRunsOnlyWhileTheBoardIsInPlay() {
        let clock = Fixtures.Clock()
        let session = session(clock)
        clock.advance(10)
        session.pauseClock()
        clock.advance(3_600)   // an hour in the background
        session.resumeClock()
        clock.advance(5)
        XCTAssertEqual(session.elapsed, 15, accuracy: 1e-9)
    }

    func testPausingTwiceOrResumingTwiceChangesNothing() {
        let clock = Fixtures.Clock()
        let session = session(clock)
        clock.advance(4)
        session.pauseClock()
        session.pauseClock()
        clock.advance(100)
        session.resumeClock()
        session.resumeClock()
        clock.advance(1)
        XCTAssertEqual(session.elapsed, 5, accuracy: 1e-9)
    }

    func testSolvingStopsTheClock() {
        let clock = Fixtures.Clock()
        let session = session(clock)
        clock.advance(42)
        session.solveCompletely()
        clock.advance(600)
        XCTAssertEqual(session.elapsed, 42, accuracy: 1e-9)
        session.resumeClock()
        clock.advance(600)
        XCTAssertEqual(session.elapsed, 42, accuracy: 1e-9, "a solved board's time is final")
    }

    func testRestartingZeroesTheClock() {
        let clock = Fixtures.Clock()
        let session = session(clock)
        clock.advance(30)
        session.reset()
        clock.advance(2)
        XCTAssertEqual(session.elapsed, 2, accuracy: 1e-9)
    }
}

final class SnapshotTests: XCTestCase {
    private let level = 47

    private func session(_ clock: Fixtures.Clock = Fixtures.Clock()) -> GameSession {
        GameSession(puzzle: Fixtures.allLevels[level - 1]) { clock.now }
    }

    /// A board with a few tiles down, some of them wrong.
    private func played(_ clock: Fixtures.Clock = Fixtures.Clock()) -> GameSession {
        let session = session(clock)
        let slots = session.puzzle.slots
        session.place(session.puzzle.solutionTile(for: slots[0])!, at: slots[0])
        session.place(session.puzzle.solutionTile(for: slots[1])!, at: slots[2])
        session.revealHint()
        clock.advance(75)
        return session
    }

    func testABoardComesBackExactlyAsItWasLeft() throws {
        let clock = Fixtures.Clock()
        let original = played(clock)
        let snapshot = original.snapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)

        let restored = session(clock)
        XCTAssertTrue(restored.restore(decoded))
        XCTAssertEqual(restored.placement, original.placement)
        XCTAssertEqual(restored.placementOrder, original.placementOrder)
        XCTAssertEqual(restored.moves, original.moves)
        XCTAssertEqual(restored.hintsUsed, original.hintsUsed)
        XCTAssertEqual(restored.elapsed, 75, accuracy: 1e-6)
        for cell in restored.puzzle.cells {
            XCTAssertEqual(restored.colour(at: cell), original.colour(at: cell))
        }
    }

    func testTheSeedSurvivesAsText() throws {
        let snapshot = played().snapshot()
        XCTAssertEqual(snapshot.seed, String(Fixtures.allLevels[level - 1].seed))
    }

    // Every way a file on disk could be wrong. Each must be refused whole,
    // leaving the board untouched — never half-applied.

    private func assertRefused(_ edit: (inout SessionSnapshot) -> Void,
                               file: StaticString = #filePath, line: UInt = #line) {
        var snapshot = played().snapshot()
        edit(&snapshot)
        let target = session()
        XCTAssertFalse(target.restore(snapshot), file: file, line: line)
        XCTAssertTrue(target.placement.isEmpty, file: file, line: line)
        XCTAssertEqual(target.moves, 0, file: file, line: line)
    }

    func testAnotherLevelsBoardIsRefused() {
        assertRefused { $0.level += 1 }
    }

    func testAnotherArcsBoardIsRefused() {
        assertRefused { $0.arc = 2 }
    }

    func testABoardFromADifferentGeneratorIsRefused() {
        assertRefused { $0.seed = "12345" }
    }

    func testAFutureFormatIsRefused() {
        assertRefused { $0.version = SessionSnapshot.currentVersion + 1 }
    }

    func testATileThatDoesNotExistIsRefused() {
        assertRefused { $0.entries[0].tile = 99_999 }
    }

    func testAClueCellIsRefused() {
        let clue = Fixtures.allLevels[level - 1].clues.first!
        assertRefused {
            $0.entries[0].x = clue.x
            $0.entries[0].y = clue.y
        }
    }

    func testATileInTwoPlacesIsRefused() {
        assertRefused { $0.entries[1].tile = $0.entries[0].tile }
    }

    func testTwoTilesInOneCellIsRefused() {
        assertRefused {
            $0.entries[1].x = $0.entries[0].x
            $0.entries[1].y = $0.entries[0].y
        }
    }

    func testImpossibleCountsAreRefused() {
        assertRefused { $0.moves = -1 }
        assertRefused { $0.moves = Int.max }
        assertRefused { $0.hintsUsed = $0.moves + 1 }
        assertRefused { $0.seconds = .nan }
        assertRefused { $0.seconds = -5 }
        assertRefused { $0.seconds = .infinity }
    }

    func testMoreEntriesThanSlotsIsRefused() {
        assertRefused { snapshot in
            snapshot.entries = Array(repeating: snapshot.entries[0], count: 500)
        }
    }

    func testASolvedBoardIsNeverRestored() {
        let solved = session()
        solved.solveCompletely()
        let snapshot = solved.snapshot()
        let target = session()
        XCTAssertFalse(target.restore(snapshot))
        XCTAssertFalse(target.isSolved)
        XCTAssertTrue(target.placement.isEmpty)
    }

    func testTheStoreKeepsOneBoardAndForgetsIt() throws {
        let directory = Fixtures.scratchDirectory()
        let store = SessionStore(directory: directory)
        XCTAssertNil(store.current)

        let snapshot = played().snapshot()
        store.save(snapshot)
        store.flush()
        XCTAssertEqual(SessionStore(directory: directory).snapshot(arc: 1, level: level), snapshot)
        XCTAssertNil(SessionStore(directory: directory).snapshot(arc: 1, level: level + 1))

        store.clear()
        store.flush()
        XCTAssertNil(SessionStore(directory: directory).current)
    }

    func testAGarbageSessionFileIsIgnored() throws {
        let directory = Fixtures.scratchDirectory()
        try Data("{ not json".utf8).write(to: directory.appendingPathComponent("session.json"))
        XCTAssertNil(SessionStore(directory: directory).current)
    }
}

/// The session now keeps a reverse index — which tile is in which cell —
/// alongside the forward one. This throws thousands of random moves at a
/// board and checks after every one that the two never disagree.
final class SessionIndexTests: XCTestCase {
    func testRandomPlayNeverLetsTheIndexesDrift() {
        var rng = TestRNG(state: 2026)
        for level in [8, 33, 71, 100] {
            let session = GameSession(puzzle: Fixtures.allLevels[level - 1])
            let slots = session.puzzle.slots
            let tiles = session.trayOrder

            for step in 0..<1_500 {
                let tile = tiles.randomElement(using: &rng)!
                switch Int.random(in: 0..<10, using: &rng) {
                case 0..<6: session.place(tile, at: slots.randomElement(using: &rng)!)
                case 6..<8: session.returnToTray(tile)
                case 8: session.revealHint()
                default:
                    // Now and then a drop somewhere that is not a slot.
                    session.place(tile, at: GridPoint(-1, -1))
                }
                if session.isSolved { session.reset() }

                // Forward and reverse agree, in both directions.
                for (id, point) in session.placement {
                    XCTAssertEqual(session.occupant[point], id, "level \(level) step \(step)")
                }
                XCTAssertEqual(session.occupant.count, session.placement.count,
                               "level \(level) step \(step)")
                // Only slots are ever occupied, and only occupied slots have
                // a place in the song.
                XCTAssertTrue(session.occupant.keys.allSatisfy(Set(slots).contains))
                XCTAssertEqual(Set(session.stamps.keys), Set(session.occupant.keys))
                XCTAssertEqual(session.remainingCount, slots.count - session.placement.count)
            }
        }
    }
}
