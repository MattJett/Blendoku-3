import XCTest
@testable import Blendoku3

/// The level book is generated, not authored, so these tests are the only thing
/// standing between a tweak to the curve and a hundred broken puzzles.
final class LevelGenerationTests: XCTestCase {
    private static let allLevels: [Puzzle] = (1...DifficultyCurve.levelCount)
        .map { PuzzleGenerator.puzzle(level: $0) }

    private var puzzles: [Puzzle] { Self.allLevels }

    func testEveryLevelBuildsWithoutFallingBack() {
        XCTAssertEqual(puzzles.count, 100)
        for puzzle in puzzles {
            // The safety-net puzzle is the only one stamped with salt 999.
            XCTAssertNotEqual(puzzle.seed, UInt64.gameSeed(level: puzzle.level, salt: 999),
                              "level \(puzzle.level) fell back to the safety net")
            XCTAssertGreaterThanOrEqual(puzzle.cells.count, 3, "level \(puzzle.level)")
            XCTAssertGreaterThanOrEqual(puzzle.slots.count, 2, "level \(puzzle.level)")
            XCTAssertFalse(puzzle.runs.isEmpty, "level \(puzzle.level)")
        }
    }

    func testEveryLevelHasExactlyOneSolution() {
        for puzzle in puzzles {
            let solver = PuzzleSolver(cells: puzzle.cells,
                                      runs: puzzle.runs,
                                      solution: puzzle.solution,
                                      open: Set(puzzle.slots),
                                      extraTiles: puzzle.tiles.filter(\.isDecoy).map(\.color))
            XCTAssertEqual(solver.countSolutions(limit: 3), 1,
                           "level \(puzzle.level) does not have a single solution")
        }
    }

    func testSolutionsAreEvenBlendsAlongEveryRun() {
        for puzzle in puzzles {
            for run in puzzle.runs {
                let colours = run.points.map { puzzle.solution[$0]! }
                let step = (colours[colours.count - 1] - colours[0]) / Double(colours.count - 1)
                for index in 1..<(colours.count - 1) {
                    let expected = colours[0] + step * Double(index)
                    XCTAssertLessThan(expected.distance(to: colours[index]), 1e-9,
                                      "level \(puzzle.level) run is not an even blend")
                }
            }
        }
    }

    func testEveryColourCanActuallyBeShown() {
        for puzzle in puzzles {
            for point in puzzle.cells {
                let colour = puzzle.solution[point]!
                XCTAssertTrue(colour.isDisplayable(margin: 0.01),
                              "level \(puzzle.level) has an out-of-gamut colour at \(point)")
            }
            for tile in puzzle.tiles {
                XCTAssertTrue(tile.color.isDisplayable(margin: 0.01), "level \(puzzle.level) tile")
            }
        }
    }

    func testNoTwoTilesLookAlike() {
        for puzzle in puzzles {
            let profile = DifficultyCurve.profile(for: puzzle.level)
            let colours = puzzle.cells.map { puzzle.solution[$0]! } + puzzle.tiles.filter(\.isDecoy).map(\.color)
            let closest = ColorFieldFactory.minimumPairDistance(colours)
            XCTAssertGreaterThanOrEqual(closest, profile.minStep * 0.77,
                                        "level \(puzzle.level) has two colours only \(closest) apart")
        }
    }

    func testTrayHoldsOneTilePerSlotPlusDecoys() {
        for puzzle in puzzles {
            let placeable = puzzle.tiles.filter { !$0.isDecoy }
            XCTAssertEqual(placeable.count, puzzle.slots.count, "level \(puzzle.level)")
            XCTAssertEqual(Set(puzzle.slots).intersection(puzzle.clues).count, 0, "level \(puzzle.level)")
            XCTAssertEqual(puzzle.clues.count + puzzle.slots.count, puzzle.cells.count,
                           "level \(puzzle.level)")
            for point in puzzle.slots {
                XCTAssertNotNil(puzzle.solutionTile(for: point), "level \(puzzle.level) slot \(point)")
            }
        }
    }

    func testGenerationIsDeterministic() {
        for level in [1, 17, 42, 73, 100] {
            let first = PuzzleGenerator.puzzle(level: level)
            let second = PuzzleGenerator.puzzle(level: level)
            XCTAssertEqual(first.cells, second.cells)
            XCTAssertEqual(first.slots, second.slots)
            XCTAssertEqual(first.tiles, second.tiles)
            XCTAssertEqual(first.solution, second.solution)
        }
    }

    func testBoardsStayWithinAPhoneScreen() {
        for puzzle in puzzles {
            XCTAssertLessThanOrEqual(puzzle.columns, 11, "level \(puzzle.level)")
            XCTAssertLessThanOrEqual(puzzle.rows, 15, "level \(puzzle.level)")
        }
    }

    func testSeparateShapesNeverTouch() {
        // Independent shapes carry independent gradients, so if two of them ever
        // ended up adjacent their lines would merge and stop blending.
        for puzzle in puzzles {
            let cells = Set(puzzle.cells)
            for run in puzzle.runs {
                let colours = run.points.map { puzzle.solution[$0]! }
                let step = (colours[1] - colours[0])
                for index in 1..<colours.count {
                    let expected = colours[0] + step * Double(index)
                    XCTAssertLessThan(expected.distance(to: colours[index]), 1e-9,
                                      "level \(puzzle.level): a run spans two shapes")
                }
            }
            XCTAssertEqual(cells.count, puzzle.cells.count)
        }
    }

    func testGeneratingTheWholeBookIsFast() {
        let started = Date()
        for level in 1...DifficultyCurve.levelCount {
            _ = PuzzleGenerator.puzzle(level: level)
        }
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, 20, "generating 100 levels took \(elapsed)s")
    }
}

final class DifficultyCurveTests: XCTestCase {
    func testStepsGetFinerEveryLevel() {
        for level in 2...DifficultyCurve.levelCount {
            let previous = DifficultyCurve.profile(for: level - 1).minStep
            let current = DifficultyCurve.profile(for: level).minStep
            XCTAssertLessThan(current, previous, "level \(level)")
        }
    }

    func testBoardsNeverShrinkOverTheCurve() {
        for level in 2...DifficultyCurve.levelCount {
            let previous = DifficultyCurve.profile(for: level - 1)
            let current = DifficultyCurve.profile(for: level)
            XCTAssertGreaterThanOrEqual(current.targetCells, previous.targetCells, "level \(level)")
            XCTAssertGreaterThanOrEqual(current.decoyCount, previous.decoyCount, "level \(level)")
        }
    }

    func testDifficultyScoreRises() {
        let first = DifficultyCurve.profile(for: 1).difficultyScore
        let middle = DifficultyCurve.profile(for: 50).difficultyScore
        let last = DifficultyCurve.profile(for: 100).difficultyScore
        XCTAssertLessThan(first, middle)
        XCTAssertLessThan(middle, last)
        XCTAssertLessThanOrEqual(last, 1)
    }

    func testLineLengthIsAffordableInColourSpace() {
        // A run of n tiles has to cross (n-1) steps of colour; sRGB cannot hold
        // much more than a lightness axis worth of travel.
        for level in 1...DifficultyCurve.levelCount {
            let profile = DifficultyCurve.profile(for: level)
            XCTAssertLessThanOrEqual(profile.minStep * Double(profile.maxSpan - 1), 0.80,
                                     "level \(level)")
            XCTAssertLessThanOrEqual(profile.maxSpan2D, profile.maxSpan, "level \(level)")
        }
    }

    func testEveryLevelHasItsOwnHue() {
        let hues = (1...DifficultyCurve.levelCount).map { DifficultyCurve.profile(for: $0).baseHue }
        XCTAssertEqual(Set(hues.map { Int($0 * 1000) }).count, hues.count, "two levels share a hue")

        // The golden angle also guarantees that levels you play back to back
        // never look like the same palette twice.
        for level in 1..<hues.count {
            let raw = abs(hues[level] - hues[level - 1])
            XCTAssertGreaterThan(min(raw, 360 - raw), 100, "levels \(level) and \(level + 1)")
        }
    }

    func testChaptersCoverEveryLevel() {
        XCTAssertEqual(Chapter.allCases.count, 10)
        let covered = Chapter.allCases.flatMap { Array($0.levels) }
        XCTAssertEqual(Set(covered), Set(1...100))
        XCTAssertEqual(Chapter.containing(level: 1), .firstLight)
        XCTAssertEqual(Chapter.containing(level: 100), .eventHorizon)
    }
}
