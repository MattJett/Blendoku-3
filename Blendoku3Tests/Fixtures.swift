import Foundation
@testable import Blendoku3

/// Shared, expensive things built once per test run.
enum Fixtures {
    /// Every level of the first arc. Generating the book takes a few seconds,
    /// so every suite that needs it shares this one copy.
    static let allLevels: [Puzzle] = (1...DifficultyCurve.levelCount)
        .map { PuzzleGenerator.puzzle(level: $0) }

    /// An empty folder of its own, for a test that writes files.
    static func scratchDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swatchword-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A clock the test moves by hand.
    final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }
}

/// A small deterministic generator, so a "random" test fails the same way
/// every time it fails.
struct TestRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
