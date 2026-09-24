import Foundation
import Observation

/// A board in progress, as written to disk.
///
/// The puzzle itself is never stored — it is regenerated from its number — so
/// this is only where each tile sits and how the attempt has gone so far.
/// `GameSession.restore` checks every field against the regenerated board
/// before trusting any of it.
struct SessionSnapshot: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var tile: Int
        var x: Int
        var y: Int
        /// Order of placement, for the song.
        var stamp: Int
    }

    static let currentVersion = 1
    static let maximumMoves = 1_000_000
    static let maximumSeconds: Double = 60 * 60 * 24 * 365

    var version = SessionSnapshot.currentVersion
    var arc: Int
    var level: Int
    /// The generator's seed, as text. It is a full 64-bit number, and JSON
    /// numbers are not guaranteed to survive a round trip at that size.
    /// Refusing a snapshot whose seed no longer matches is what stops a board
    /// saved by one build being laid onto a different board by the next.
    var seed: String
    var entries: [Entry]
    var moves: Int
    var hintsUsed: Int
    var seconds: Double
}

/// The one board the player left unfinished.
///
/// Only ever one: this is "carry on where you were", not a save-slot system.
/// Opening any other level and making a move replaces it.
@Observable
final class SessionStore {
    private(set) var current: SessionSnapshot?

    private let fileURL: URL
    private let queue = DispatchQueue(label: "swatchword.session", qos: .utility)

    init(directory: URL = Storage.directory, filename: String = "session.json") {
        fileURL = directory.appendingPathComponent(filename)
        if let data = Storage.read(fileURL) {
            current = try? JSONDecoder().decode(SessionSnapshot.self, from: data)
        }
    }

    func snapshot(arc: Int, level: Int) -> SessionSnapshot? {
        guard let current, current.arc == arc, current.level == level else { return nil }
        return current
    }

    func save(_ snapshot: SessionSnapshot) {
        guard snapshot != current else { return }
        current = snapshot
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            Storage.write(data, to: url)
        }
    }

    func clear() {
        guard current != nil else { return }
        current = nil
        let url = fileURL
        queue.async { try? FileManager.default.removeItem(at: url) }
    }

    /// Blocks until every queued write has landed.
    func flush() {
        queue.sync {}
    }
}
