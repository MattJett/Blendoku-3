import XCTest
@testable import Blendoku3

final class PuzzleSolverTests: XCTestCase {
    /// A straight line of three, blending evenly.
    private func makeRow(_ count: Int) -> (cells: [GridPoint], runs: [PuzzleRun], solution: [GridPoint: BlendColor]) {
        let cells = (0..<count).map { GridPoint($0, 0) }
        var solution: [GridPoint: BlendColor] = [:]
        for (index, point) in cells.enumerated() {
            solution[point] = BlendColor(lightness: 0.30 + 0.15 * Double(index), chroma: 0.10, hue: 200)
        }
        return (cells, RunFinder.runs(in: Set(cells)), solution)
    }

    func testAnchorAtTheEndGivesOneSolution() {
        let (cells, runs, solution) = makeRow(3)
        let solver = PuzzleSolver(cells: cells, runs: runs, solution: solution,
                                  open: [GridPoint(1, 0), GridPoint(2, 0)])
        XCTAssertEqual(solver.countSolutions(limit: 5), 1)
    }

    /// Documents why the generator cannot simply leave the middle tile fixed:
    /// a progression read from its centre works in both directions.
    func testAnchorInTheMiddleIsAmbiguous() {
        let (cells, runs, solution) = makeRow(3)
        let solver = PuzzleSolver(cells: cells, runs: runs, solution: solution,
                                  open: [GridPoint(0, 0), GridPoint(2, 0)])
        XCTAssertEqual(solver.countSolutions(limit: 5), 2)
    }

    func testDecoyThatFitsNowhereDoesNotAddSolutions() {
        let (cells, runs, solution) = makeRow(3)
        let decoy = BlendColor(lightness: 0.9, chroma: 0.02, hue: 10)
        let solver = PuzzleSolver(cells: cells, runs: runs, solution: solution,
                                  open: [GridPoint(1, 0), GridPoint(2, 0)],
                                  extraTiles: [decoy])
        XCTAssertEqual(solver.countSolutions(limit: 5), 1)
    }

    func testCrossingLinesConstrainEachOther() {
        let cells = [GridPoint(1, 0), GridPoint(0, 1), GridPoint(1, 1), GridPoint(2, 1), GridPoint(1, 2)]
        let origin = BlendColor(lightness: 0.5, chroma: 0.08, hue: 120)
        let dx = BlendColor(l: 0, a: 0.06, b: 0.01)
        let dy = BlendColor(l: 0.12, a: 0, b: -0.02)
        var solution: [GridPoint: BlendColor] = [:]
        for point in cells {
            solution[point] = origin + dx * Double(point.x) + dy * Double(point.y)
        }
        let runs = RunFinder.runs(in: Set(cells))
        XCTAssertEqual(runs.count, 2)

        let tight = PuzzleSolver(cells: cells, runs: runs, solution: solution,
                                 open: [GridPoint(0, 1), GridPoint(1, 0)])
        XCTAssertEqual(tight.countSolutions(limit: 5), 1)

        // Emptying both arms of both lines leaves the tiles interchangeable.
        let loose = PuzzleSolver(cells: cells, runs: runs, solution: solution,
                                 open: [GridPoint(0, 1), GridPoint(1, 0), GridPoint(2, 1), GridPoint(1, 2)])
        XCTAssertGreaterThan(loose.countSolutions(limit: 2), 1)
    }

    func testRunFinderIgnoresPairs() {
        // An L of two-by-two has no run of three, so nothing is constrained.
        let cells: Set<GridPoint> = [GridPoint(0, 0), GridPoint(1, 0), GridPoint(0, 1)]
        XCTAssertTrue(RunFinder.runs(in: cells).isEmpty)
    }

    func testRunFinderFindsBothAxes() {
        let cells = Set((0..<3).flatMap { y in (0..<3).map { GridPoint($0, y) } })
        let runs = RunFinder.runs(in: cells)
        XCTAssertEqual(runs.filter { $0.axis == .horizontal }.count, 3)
        XCTAssertEqual(runs.filter { $0.axis == .vertical }.count, 3)
    }
}
