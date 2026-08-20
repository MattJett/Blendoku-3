import XCTest
@testable import Blendoku3

/// The corner rule is what makes a run of tiles read as one continuous blend
/// rather than a row of separate chips, so it is worth pinning down.
@MainActor
final class BoardLayoutTests: XCTestCase {
    private func corners(_ point: GridPoint, _ cells: [GridPoint]) -> TileCorners {
        BoardView.corners(at: point, in: Set(cells))
    }

    func testALoneTileIsRoundedAllRound() {
        XCTAssertEqual(corners(GridPoint(0, 0), [GridPoint(0, 0)]), .all)
    }

    func testTheMiddleOfARunHasNoRoundedCorners() {
        let run = (0..<3).map { GridPoint($0, 0) }
        XCTAssertEqual(corners(GridPoint(1, 0), run), [])
    }

    func testTheEndsOfARunRoundOnlyTheirOutsideCorners() {
        let run = (0..<3).map { GridPoint($0, 0) }
        XCTAssertEqual(corners(GridPoint(0, 0), run), [.topLeading, .bottomLeading])
        XCTAssertEqual(corners(GridPoint(2, 0), run), [.topTrailing, .bottomTrailing])
    }

    func testAVerticalRunRoundsTopAndBottom() {
        let column = (0..<3).map { GridPoint(0, $0) }
        XCTAssertEqual(corners(GridPoint(0, 0), column), [.topLeading, .topTrailing])
        XCTAssertEqual(corners(GridPoint(0, 1), column), [])
        XCTAssertEqual(corners(GridPoint(0, 2), column), [.bottomLeading, .bottomTrailing])
    }

    /// The elbow of an L: the outside of the bend rounds, the inside stays a
    /// right angle so the two arms meet cleanly.
    func testTheInsideOfABendStaysSquare() {
        let elbow = [GridPoint(0, 0), GridPoint(1, 0), GridPoint(1, 1)]
        XCTAssertEqual(corners(GridPoint(1, 0), elbow), [.topTrailing])
        XCTAssertEqual(corners(GridPoint(0, 0), elbow), [.topLeading, .bottomLeading])
        XCTAssertEqual(corners(GridPoint(1, 1), elbow), [.bottomLeading, .bottomTrailing])
    }

    func testTheCentreOfACrossIsFullySquare() {
        let cross = [GridPoint(1, 0), GridPoint(0, 1), GridPoint(1, 1),
                     GridPoint(2, 1), GridPoint(1, 2)]
        XCTAssertEqual(corners(GridPoint(1, 1), cross), [])
        XCTAssertEqual(corners(GridPoint(1, 0), cross), [.topLeading, .topTrailing])
    }

    /// Every generated level should have at least one tile that is not fully
    /// rounded — otherwise nothing would be touching and the point is lost.
    func testRealLevelsHaveTilesThatTouch() {
        for level in [4, 22, 55, 84, 100] {
            let puzzle = PuzzleGenerator.puzzle(level: level)
            let cells = Set(puzzle.cells)
            let touching = puzzle.cells.filter { BoardView.corners(at: $0, in: cells) != .all }
            XCTAssertFalse(touching.isEmpty, "level \(level) has no adjacent tiles at all")
        }
    }

    func testBoardTilesFillTheirCellSoNeighboursMeet() {
        let metrics = BoardView.Metrics(columns: 4, rows: 6,
                                        available: CGSize(width: 320, height: 480))
        XCTAssertEqual(metrics.tile, metrics.step, accuracy: 1e-9)
        XCTAssertGreaterThan(metrics.bleed, 0)
    }
}
