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
}

/// Saved progress and settings. Small enough to keep as one JSON file.
@Observable
final class ProgressStore {
    private(set) var records: [Int: LevelRecord] = [:]
    private(set) var lastPlayedLevel = 1

    private let fileURL: URL
    private let queue = DispatchQueue(label: "blendoku.progress", qos: .utility)

    init(filename: String = "progress.json") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        fileURL = base.appendingPathComponent(filename)
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

    // MARK: - Writing

    func complete(level: Int, moves: Int, seconds: Double, hintsUsed: Int, perfectMoves: Int) {
        let candidate = LevelRecord(level: level, moves: moves, seconds: seconds,
                                    hintsUsed: hintsUsed, perfectMoves: perfectMoves)
        if let existing = records[level] {
            // Keep whichever attempt went better.
            let better = candidate.stars > existing.stars
                || (candidate.stars == existing.stars && candidate.moves < existing.moves)
            if !better { lastPlayedLevel = level; save(); return }
        }
        records[level] = candidate
        lastPlayedLevel = level
        save()
    }

    func markPlayed(level: Int) {
        lastPlayedLevel = level
        save()
    }

    func resetEverything() {
        records = [:]
        lastPlayedLevel = 1
        save()
    }

    // MARK: - Disk

    private struct Payload: Codable {
        var records: [LevelRecord]
        var lastPlayedLevel: Int
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        records = Dictionary(uniqueKeysWithValues: payload.records.map { ($0.level, $0) })
        lastPlayedLevel = payload.lastPlayedLevel
    }

    private func save() {
        let payload = Payload(records: Array(records.values).sorted { $0.level < $1.level },
                              lastPlayedLevel: lastPlayedLevel)
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
