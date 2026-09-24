import Foundation
import Observation

/// A keepsake: a finished board's blend, and — since version 2 — its song.
///
/// Stored as hex strings rather than as Oklab triples, deliberately. Hex is
/// what the CSS is made of, so it is the form the saved thing is actually
/// *for*; it is readable if anyone ever opens the file; and it does not move if
/// the Oklab implementation is ever refined. A saved palette should still be
/// the same colours in five years even if the colour maths underneath it has
/// been rewritten.
struct SavedBlend: Codable, Hashable, Sendable, Identifiable {
    var id: UUID = UUID()
    /// Which Chromarc and level it came from. The arc is recorded even though
    /// only one exists, so blends kept today still say where they came from
    /// once there are several.
    var arc: Int = 1
    var level: Int
    var savedAt: Date = Date()
    var swatches: [String]

    /// The tiles in the order they were placed. Optional because version 1
    /// keepsakes predate songs; they still open, they just have no tune.
    var melody: [String]?
    /// Every cell on the board, for the climb.
    var spectrum: [String]?
    /// The level's instrument.
    var warmth: Double?

    var colours: [BlendColor] { swatches.compactMap(BlendColor.init(hex:)) }

    /// The CSS declaration this blend was kept for.
    var css: String { GradientRibbon.css(colours) }

    var title: String { "Arc \(arc) · Level \(level)" }

    /// The name shown on the shelf.
    var label: String {
        "\(Chromarc.numbered(arc).title) \(String(format: "%03d", level))"
    }

    var hasSong: Bool { song != nil }

    /// The song, rebuilt from its colours.
    var song: SongSchedule? {
        let notes = (melody ?? []).compactMap(BlendColor.init(hex:))
        let cells = (spectrum ?? []).compactMap(BlendColor.init(hex:))
        guard !notes.isEmpty, !cells.isEmpty else { return nil }
        return SongSchedule(melody: notes, spectrum: cells)
    }

    /// Whether a keepsake read back from disk could have been written by the
    /// game. Generous bounds; the point is to refuse garbage before anything
    /// tries to draw or play it.
    var isPlausible: Bool {
        (1...99).contains(arc)
            && (1...DifficultyCurve.levelCount).contains(level)
            && (2...256).contains(swatches.count)
            && (melody?.count ?? 0) <= 256
            && (spectrum?.count ?? 0) <= 256
            && (warmth.map { $0.isFinite && (0...1).contains($0) } ?? true)
    }
}

/// The keepsakes the player has kept.
///
/// Versioned from its first commit, which progress deliberately is not.
/// Progress can be earned again; a palette someone chose to keep cannot be
/// reconstructed from anything. That difference is worth a schema number and a
/// refusal to overwrite a file written by a build newer than this one.
@Observable
final class BlendLibrary {
    private(set) var blends: [SavedBlend] = []
    /// Set when the file on disk came from a newer build. Everything still
    /// reads, but nothing is written back — losing a saved blend to a version
    /// downgrade is exactly the failure the version number exists to prevent.
    private(set) var isReadOnly = false

    /// Version 2 added the song. Every field it added is optional, so a
    /// version 1 file reads as-is and simply has no songs in it.
    static let currentVersion = 2
    /// More than anyone will keep, and a ceiling on what a damaged file can
    /// make the shelf try to draw.
    static let capacity = 500

    private let fileURL: URL
    private let queue = DispatchQueue(label: "swatchword.blends", qos: .utility)

    init(directory: URL = Storage.directory, filename: String = "blends.json") {
        fileURL = directory.appendingPathComponent(filename)
        load()
    }

    // MARK: - Queries

    var isEmpty: Bool { blends.isEmpty }

    var songCount: Int { blends.filter(\.hasSong).count }

    func saved(arc: Int, level: Int) -> SavedBlend? {
        blends.first { $0.arc == arc && $0.level == level }
    }

    // MARK: - Writing

    /// Keeping the same level twice replaces the earlier entry rather than
    /// stacking duplicates — replaying a board to get a cleaner solve should
    /// not litter the shelf.
    @discardableResult
    func keep(level: Int, arc: Int = 1, colours: [BlendColor],
              melody: [BlendColor] = [], spectrum: [BlendColor] = [],
              warmth: Double? = nil) -> SavedBlend {
        let blend = SavedBlend(arc: arc, level: level,
                               swatches: colours.map(\.hexString),
                               melody: melody.isEmpty ? nil : melody.map(\.hexString),
                               spectrum: spectrum.isEmpty ? nil : spectrum.map(\.hexString),
                               warmth: warmth.map { min(max($0, 0), 1) })
        blends.removeAll { $0.arc == arc && $0.level == level }
        blends.insert(blend, at: 0)
        if blends.count > Self.capacity { blends.removeLast(blends.count - Self.capacity) }
        save()
        return blend
    }

    func remove(_ blend: SavedBlend) {
        blends.removeAll { $0.id == blend.id }
        save()
    }

    func removeAll() {
        blends.removeAll()
        save()
    }

    /// Blocks until every queued write has landed.
    ///
    /// Writes go out on a background queue so keeping a blend never stalls a
    /// tap. That is right for the app and wrong for anyone who needs to know
    /// the disk caught up — a test reading the file back, or a save on the way
    /// to the background. The queue is serial, so a `sync` after an `async`
    /// returns only once the earlier block has finished.
    func flush() {
        queue.sync {}
    }

    #if DEBUG
    /// Fills the shelf in memory with keepsakes from real boards, for
    /// screenshots of Keepsakes. Nothing is written.
    func preview() {
        blends = [12, 31, 58].map { level in
            let puzzle = PuzzleGenerator.puzzle(level: level)
            let colour = { (point: GridPoint) in puzzle.solution[point] }
            return SavedBlend(arc: 1, level: level,
                              savedAt: Date(timeIntervalSince1970: 1_790_000_000 - Double(level) * 86_400),
                              swatches: puzzle.paletteSwatches(count: 14).map(\.hexString),
                              melody: level == 31 ? nil : puzzle.slots.compactMap(colour).map(\.hexString),
                              spectrum: level == 31 ? nil : puzzle.cells.compactMap(colour).map(\.hexString),
                              warmth: 0.5)
        }
    }
    #endif

    // MARK: - Disk

    private struct Payload: Codable {
        var version: Int
        var blends: [SavedBlend]
    }

    private func load() {
        guard let data = Storage.read(fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        blends = Array(payload.blends.filter(\.isPlausible).prefix(Self.capacity))
        isReadOnly = payload.version > Self.currentVersion
    }

    private func save() {
        guard !isReadOnly else { return }
        let payload = Payload(version: Self.currentVersion, blends: blends)
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(payload) else { return }
            Storage.write(data, to: url)
        }
    }
}
