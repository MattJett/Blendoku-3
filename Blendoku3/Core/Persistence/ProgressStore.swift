import Foundation
import Observation

/// What the player achieved on one level.
struct LevelRecord: Codable, Hashable, Sendable {
    var level: Int
    var moves: Int
    var seconds: Double
    var hintsUsed: Int

    /// Three stars for a clean solve, fewer for hints or wandering.
    var stars: Int {
        if hintsUsed > 0 { return 1 }
        return moves <= perfectMoves ? 3 : (moves <= perfectMoves * 2 ? 2 : 1)
    }

    /// Set when the record is written; the fewest moves the level can take.
    var perfectMoves: Int = 1

    /// Whether a record read back from disk could have been written by the
    /// game. The bounds are far past anything real; what they rule out is
    /// garbage — and in particular a `perfectMoves` large enough that doubling
    /// it for the star count would overflow and take the app down.
    var isPlausible: Bool {
        (1...DifficultyCurve.levelCount).contains(level)
            && (0...SessionSnapshot.maximumMoves).contains(moves)
            && (0...SessionSnapshot.maximumMoves).contains(hintsUsed)
            && (1...10_000).contains(perfectMoves)
            && seconds.isFinite && seconds >= 0
    }

    /// Fewer stars loses; at equal stars, fewer moves wins.
    func isBetter(than other: LevelRecord) -> Bool {
        stars > other.stars || (stars == other.stars && moves < other.moves)
    }
}

/// Saved progress. Small enough to keep as one JSON file.
@Observable
final class ProgressStore {
    private(set) var records: [Int: LevelRecord] = [:]
    private(set) var lastPlayedLevel = 1

    private let fileURL: URL
    private let queue = DispatchQueue(label: "blendoku.progress", qos: .utility)

    init(directory: URL = Storage.directory, filename: String = "progress.json") {
        fileURL = directory.appendingPathComponent(filename)
        load()
    }

    // MARK: - Queries

    func record(for level: Int) -> LevelRecord? { records[level] }

    func isCompleted(_ level: Int) -> Bool { records[level] != nil }

    /// Levels unlock one at a time, but finishing a chapter opens the next one
    /// even if a level inside it was skipped by an earlier build.
    func isUnlocked(_ level: Int) -> Bool {
        level <= 1 || records[level - 1] != nil || records[level] != nil
    }

    var furthestUnlocked: Int {
        var level = 1
        while level < DifficultyCurve.levelCount && records[level] != nil { level += 1 }
        return level
    }

    var completedCount: Int { records.count }

    var totalStars: Int { records.values.reduce(0) { $0 + $1.stars } }

    var isArcComplete: Bool { completedCount >= DifficultyCurve.levelCount }

    /// How many of an arc's hundred are solved. Only the first arc is built,
    /// so only it can have any.
    func completed(in arc: Chromarc) -> Int {
        arc.number == 1 ? completedCount : 0
    }

    // MARK: - Writing

    func complete(level: Int, moves: Int, seconds: Double, hintsUsed: Int, perfectMoves: Int) {
        let candidate = LevelRecord(level: level, moves: moves, seconds: seconds,
                                    hintsUsed: hintsUsed, perfectMoves: max(1, perfectMoves))
        lastPlayedLevel = level
        if let existing = records[level], !candidate.isBetter(than: existing) {
            save()
            return
        }
        records[level] = candidate
        save()
    }

    func markPlayed(level: Int) {
        guard lastPlayedLevel != level else { return }
        lastPlayedLevel = level
        save()
    }

    func resetEverything() {
        records = [:]
        lastPlayedLevel = 1
        save()
    }

    /// Blocks until every queued write has landed. Called on the way to the
    /// background, where the process may not get another chance.
    func flush() {
        queue.sync {}
    }

    #if DEBUG
    /// Marks the first `count` levels solved in memory only, for screenshots.
    /// Nothing is written.
    func preview(solved count: Int) {
        let upper = min(max(count, 0), DifficultyCurve.levelCount)
        guard upper > 0 else { return }
        for level in 1...upper where records[level] == nil {
            records[level] = LevelRecord(level: level, moves: 4, seconds: 30, hintsUsed: 0,
                                         perfectMoves: level % 3 == 0 ? 3 : 4)
        }
    }
    #endif

    // MARK: - Disk

    private struct Payload: Codable {
        var records: [LevelRecord]
        var lastPlayedLevel: Int
    }

    /// Anything implausible is dropped rather than trusted, and a level that
    /// appears twice keeps its better attempt. The old loader built its table
    /// with `uniqueKeysWithValues`, which *traps* on a duplicate — so one bad
    /// line in the file would have crashed the app on every launch after it.
    private func load() {
        guard let data = Storage.read(fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        var loaded: [Int: LevelRecord] = [:]
        for record in payload.records where record.isPlausible {
            if let existing = loaded[record.level], !record.isBetter(than: existing) { continue }
            loaded[record.level] = record
        }
        records = loaded
        lastPlayedLevel = min(max(payload.lastPlayedLevel, 1), DifficultyCurve.levelCount)
    }

    private func save() {
        let payload = Payload(records: Array(records.values).sorted { $0.level < $1.level },
                              lastPlayedLevel: lastPlayedLevel)
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(payload) else { return }
            Storage.write(data, to: url)
        }
    }
}
