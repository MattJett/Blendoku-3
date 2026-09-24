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

    @ObservationIgnored private var cache: [Key: Puzzle] = [:]
    /// Boards being built right now. Asking for one that is already on its
    /// way waits for that build instead of starting a second — which is what
    /// used to happen whenever the player tapped Next faster than the
    /// prefetch finished.
    @ObservationIgnored private var pending: [Key: Task<Puzzle, Never>] = [:]

    var levelCount: Int { DifficultyCurve.levelCount }

    func cached(_ level: Int, arc: Int = 1) -> Puzzle? { cache[Key(arc: arc, level: level)] }

    func puzzle(for level: Int, arc: Int = 1) async -> Puzzle {
        let key = Key(arc: arc, level: level)
        if let existing = cache[key] { return existing }
        let task = pending[key] ?? build(key, priority: .userInitiated)
        return await task.value
    }

    /// Warms the next couple of levels while the player is busy with this one.
    func prefetch(after level: Int, arc: Int = 1, count: Int = 2) {
        guard level < levelCount else { return }
        for next in (level + 1)...min(level + count, levelCount) {
            let key = Key(arc: arc, level: next)
            guard cache[key] == nil, pending[key] == nil else { continue }
            _ = build(key, priority: .utility)
        }
    }

    private func build(_ key: Key, priority: TaskPriority) -> Task<Puzzle, Never> {
        let generation = Task.detached(priority: priority) {
            PuzzleGenerator.puzzle(level: key.level, arc: key.arc)
        }
        let task = Task { @MainActor [weak self] () -> Puzzle in
            let built = await generation.value
            self?.cache[key] = built
            self?.pending[key] = nil
            return built
        }
        pending[key] = task
        return task
    }
}
