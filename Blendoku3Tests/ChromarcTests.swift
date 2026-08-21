import XCTest
@testable import Blendoku3

/// Chromarc 1 is the hundred levels that already existed. Nothing about adding
/// arcs is allowed to move a single one of them.
final class ChromarcTests: XCTestCase {

    /// The seed function exactly as it was before arcs, kept here on purpose:
    /// a test that compares the new code to itself proves nothing.
    private func legacySeed(level: Int, salt: UInt64) -> UInt64 {
        var value = UInt64(bitPattern: Int64(level)) &* 0x9E3779B97F4A7C15
        value ^= salt &* 0xC2B2AE3D27D4EB4F
        value = (value ^ (value >> 29)) &* 0xBF58476D1CE4E5B9
        return value ^ (value >> 32)
    }

    func testArcOneSeedsMatchTheOnesFromBeforeArcsExisted() {
        for level in 1...DifficultyCurve.levelCount {
            for salt in [UInt64(0), 1, 7, 63, 179] {
                XCTAssertEqual(UInt64.gameSeed(arc: 1, level: level, salt: salt),
                               legacySeed(level: level, salt: salt),
                               "level \(level), salt \(salt)")
            }
        }
    }

    func testAnotherArcIsADifferentStream() {
        var collisions = 0
        for level in 1...DifficultyCurve.levelCount {
            let one = UInt64.gameSeed(arc: 1, level: level, salt: 0)
            let two = UInt64.gameSeed(arc: 2, level: level, salt: 0)
            if one == two { collisions += 1 }
        }
        XCTAssertEqual(collisions, 0, "arc 2 reproduced arc 1's boards")
    }

    func testArcOneSpansTheWholeCurve() {
        for level in 1...DifficultyCurve.levelCount {
            let expected = Double(level - 1) / Double(DifficultyCurve.levelCount - 1)
            XCTAssertEqual(Chromarc.first.progress(at: level), expected, accuracy: 1e-12)
        }
    }

    func testArcOneProfilesAreUnchangedByTheArcArgument() {
        for level in 1...DifficultyCurve.levelCount {
            let bare = DifficultyCurve.profile(for: level)
            let explicit = DifficultyCurve.profile(for: level, arc: 1)
            XCTAssertEqual(bare.targetCells, explicit.targetCells, "level \(level)")
            XCTAssertEqual(bare.targetSlots, explicit.targetSlots, "level \(level)")
            XCTAssertEqual(bare.minStep, explicit.minStep, accuracy: 1e-15, "level \(level)")
        }
    }

    func testALaterArcOpensPartwayAlongTheCurve() {
        let second = Chromarc.second
        XCTAssertEqual(second.progress(at: 1), second.span.lowerBound, accuracy: 1e-12)
        XCTAssertEqual(second.progress(at: DifficultyCurve.levelCount),
                       second.span.upperBound, accuracy: 1e-12)
        // Its first board should be a real board, not a three-cell tutorial.
        let opening = DifficultyCurve.profile(for: 1, arc: 2)
        XCTAssertGreaterThan(opening.targetCells,
                             DifficultyCurve.profile(for: 1, arc: 1).targetCells)
    }

    func testOnlyTheFirstArcIsPlayableSoFar() {
        XCTAssertTrue(Chromarc.first.isPlayable)
        XCTAssertFalse(Chromarc.second.isPlayable)
        XCTAssertEqual(Chromarc.numbered(99).number, 1, "unknown arcs fall back to the first")
    }

    func testPuzzlesCarryTheirArc() {
        XCTAssertEqual(PuzzleGenerator.puzzle(level: 3).arc, 1)
        XCTAssertEqual(PuzzleGenerator.puzzle(level: 3, arc: 2).arc, 2)
    }
}
