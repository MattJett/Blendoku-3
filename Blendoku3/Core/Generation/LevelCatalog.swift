import Foundation
import Observation

/// Hands out puzzles, generating them off the main thread and keeping what it
/// has already built. Generation is deterministic, so a level looks the same
/// on every device and every launch — there is nothing to ship or download.
@MainActor
@Observable
final class LevelCatalog {
    /// Keyed by arc as well as level: two arcs share level numbers but not
    /// boards, and a cache that forgot which was which would hand the player
    /// the wrong puzzle.
    struct Key: Hashable, Sendable {
        var arc: Int
        var level: Int
    }

    private var cache: [Key: Puzzle] = [:]
    private var inFlight: Set<Key> = []

    var levelCount: Int { DifficultyCurve.levelCount }

    func cached(_ level: Int, arc: Int = 1) -> Puzzle? { cache[Key(arc: arc, level: level)] }

    func puzzle(for level: Int, arc: Int = 1) async -> Puzzle {
        let key = Key(arc: arc, level: level)
        if let existing = cache[key] { return existing }
        let built = await Task.detached(priority: .userInitiated) {
            PuzzleGenerator.puzzle(level: level, arc: arc)
        }.value
        cache[key] = built
        return built
    }

    /// Warms the next couple of levels while the player is busy with this one.
    func prefetch(after level: Int, arc: Int = 1, count: Int = 2) {
        for next in (level + 1)...(level + count) where next <= levelCount {
            let key = Key(arc: arc, level: next)
            guard cache[key] == nil, !inFlight.contains(key) else { continue }
            inFlight.insert(key)
            Task {
                let built = await Task.detached(priority: .background) {
                    PuzzleGenerator.puzzle(level: next, arc: arc)
                }.value
                cache[key] = built
                inFlight.remove(key)
            }
        }
    }
}
