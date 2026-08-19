import XCTest
@testable import Blendoku3

final class GameSessionTests: XCTestCase {
    private func session(level: Int = 24) -> GameSession {
        GameSession(puzzle: PuzzleGenerator.puzzle(level: level))
    }

    func testStartsEmptyAndUnsolved() {
        let session = session()
        XCTAssertFalse(session.isSolved)
        XCTAssertEqual(session.moves, 0)
        XCTAssertEqual(session.remainingCount, session.puzzle.slots.count)
        for slot in session.puzzle.slots {
            XCTAssertNil(session.colour(at: slot))
        }
        for clue in session.puzzle.clues {
            XCTAssertNotNil(session.colour(at: clue))
        }
    }

    func testPlacingAndReturningATile() {
        let session = session()
        let slot = session.puzzle.slots[0]
        let tile = session.puzzle.solutionTile(for: slot)!

        XCTAssertTrue(session.place(tile, at: slot))
        XCTAssertEqual(session.colour(at: slot), tile.color)
        XCTAssertFalse(session.isInTray(tile))
        XCTAssertEqual(session.moves, 1)

        XCTAssertTrue(session.returnToTray(tile))
        XCTAssertNil(session.colour(at: slot))
        XCTAssertTrue(session.isInTray(tile))
        XCTAssertEqual(session.moves, 2)
    }

    func testDroppingOnAFilledSlotSwapsTheTiles() throws {
        let session = session()
        try XCTSkipUnless(session.puzzle.slots.count >= 2)
        let first = session.puzzle.slots[0]
        let second = session.puzzle.slots[1]
        let tileA = session.puzzle.solutionTile(for: first)!
        let tileB = session.puzzle.solutionTile(for: second)!

        session.place(tileA, at: first)
        session.place(tileB, at: second)
        // Move A onto B's slot: B should be pushed back to where A was.
        session.place(tileA, at: second)

        XCTAssertEqual(session.colour(at: second), tileA.color)
        XCTAssertEqual(session.colour(at: first), tileB.color)
    }

    func testDroppingOnACluePositionIsRefused() {
        let session = session()
        guard let clue = session.puzzle.clues.first else { return XCTFail("no clues") }
        let tile = session.puzzle.solutionTile(for: session.puzzle.slots[0])!
        XCTAssertFalse(session.place(tile, at: clue))
        XCTAssertEqual(session.moves, 0)
        XCTAssertEqual(session.rejectionCount, 1)
    }

    func testCompletingTheBoardSolvesIt() {
        for level in [3, 24, 55, 88] {
            let session = GameSession(puzzle: PuzzleGenerator.puzzle(level: level))
            session.solveCompletely()
            XCTAssertTrue(session.isSolved, "level \(level) did not register as solved")
            XCTAssertEqual(session.satisfiedRuns.count, session.puzzle.runs.count)
            XCTAssertNotNil(session.solvedAt)
            XCTAssertEqual(session.remainingCount, 0)
        }
    }

    func testAWrongArrangementIsNotSolved() throws {
        let session = session(level: 40)
        try XCTSkipUnless(session.puzzle.slots.count >= 2)
        let slots = session.puzzle.slots
        let tiles = slots.map { session.puzzle.solutionTile(for: $0)! }
        // Deliberately place the first two tiles the wrong way round.
        session.place(tiles[1], at: slots[0])
        session.place(tiles[0], at: slots[1])
        for index in 2..<slots.count {
            session.place(tiles[index], at: slots[index])
        }
        XCTAssertFalse(session.isSolved)
    }

    func testHintPlacesACorrectTile() {
        let session = session(level: 33)
        let target = session.revealHint()
        XCTAssertNotNil(target)
        XCTAssertTrue(session.isCorrect(at: target!))
        XCTAssertEqual(session.hintsUsed, 1)
    }

    func testRepeatedHintsFinishTheBoard() {
        let session = session(level: 12)
        for _ in 0..<(session.puzzle.slots.count + 2) {
            _ = session.revealHint()
        }
        XCTAssertTrue(session.isSolved)
    }

    func testResetPutsEverythingBack() {
        let session = session()
        session.solveCompletely()
        session.reset()
        XCTAssertFalse(session.isSolved)
        XCTAssertEqual(session.moves, 0)
        XCTAssertEqual(session.remainingCount, session.puzzle.slots.count)
        XCTAssertTrue(session.trayOrder.allSatisfy(session.isInTray))
    }

    func testProgressTracksPlacements() {
        let session = session(level: 20)
        XCTAssertEqual(session.progress, 0, accuracy: 1e-9)
        session.solveCompletely()
        XCTAssertEqual(session.progress, 1, accuracy: 1e-9)
    }
}

final class ProgressStoreTests: XCTestCase {
    private func store() -> ProgressStore {
        ProgressStore(filename: "test-progress-\(UUID().uuidString).json")
    }

    func testFirstLevelIsUnlockedAndTheRestAreNot() {
        let store = store()
        XCTAssertTrue(store.isUnlocked(1))
        XCTAssertFalse(store.isUnlocked(2))
        XCTAssertEqual(store.furthestUnlocked, 1)
    }

    func testCompletingALevelUnlocksTheNext() {
        let store = store()
        store.complete(level: 1, moves: 2, seconds: 8, hintsUsed: 0, perfectMoves: 2)
        XCTAssertTrue(store.isUnlocked(2))
        XCTAssertEqual(store.furthestUnlocked, 2)
        XCTAssertEqual(store.record(for: 1)?.stars, 3)
    }

    func testHintsCostStars() {
        let store = store()
        store.complete(level: 1, moves: 2, seconds: 8, hintsUsed: 1, perfectMoves: 2)
        XCTAssertEqual(store.record(for: 1)?.stars, 1)
    }

    func testABetterAttemptReplacesAWorseOne() {
        let store = store()
        store.complete(level: 4, moves: 30, seconds: 90, hintsUsed: 0, perfectMoves: 4)
        XCTAssertEqual(store.record(for: 4)?.stars, 1)
        store.complete(level: 4, moves: 4, seconds: 20, hintsUsed: 0, perfectMoves: 4)
        XCTAssertEqual(store.record(for: 4)?.stars, 3)
        // A worse run afterwards must not overwrite the good one.
        store.complete(level: 4, moves: 44, seconds: 200, hintsUsed: 0, perfectMoves: 4)
        XCTAssertEqual(store.record(for: 4)?.stars, 3)
    }

    func testResetClearsEverything() {
        let store = store()
        store.complete(level: 1, moves: 2, seconds: 8, hintsUsed: 0, perfectMoves: 2)
        store.resetEverything()
        XCTAssertEqual(store.completedCount, 0)
        XCTAssertFalse(store.isUnlocked(2))
    }
}
