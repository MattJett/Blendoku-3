import Foundation
import Observation

/// Hands out puzzles, generating them off the main thread and keeping what it
/// has already built. Generation is deterministic, so a level looks the same
/// on every device and every launch — there is nothing to ship or download.
@MainActor
@Observable
final class LevelCatalog {
    private var cache: [Int: Puzzle] = [:]
    private var inFlight: Set<Int> = []

    var levelCount: Int { DifficultyCurve.levelCount }

    func cached(_ level: Int) -> Puzzle? { cache[level] }

    func puzzle(for level: Int) async -> Puzzle {
        if let existing = cache[level] { return existing }
        let built = await Task.detached(priority: .userInitiated) {
            PuzzleGenerator.puzzle(level: level)
        }.value
        cache[level] = built
        return built
    }

    /// Warms the next couple of levels while the player is busy with this one.
    func prefetch(after level: Int, count: Int = 2) {
        for next in (level + 1)...(level + count) where next <= levelCount {
            guard cache[next] == nil, !inFlight.contains(next) else { continue }
            inFlight.insert(next)
            Task {
                let built = await Task.detached(priority: .background) {
                    PuzzleGenerator.puzzle(level: next)
                }.value
                cache[next] = built
                inFlight.remove(next)
            }
        }
    }
}
