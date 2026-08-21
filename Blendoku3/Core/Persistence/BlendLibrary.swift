import Foundation
import Observation

/// A blend the player kept.
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

    var colours: [BlendColor] { swatches.compactMap(BlendColor.init(hex:)) }

    /// The CSS declaration this blend was kept for.
    var css: String { GradientRibbon.css(colours) }

    var title: String { "Arc \(arc) · Level \(level)" }
}

/// The blends the player has kept.
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

    static let currentVersion = 1

    private let fileURL: URL
    private let queue = DispatchQueue(label: "swatchword.blends", qos: .utility)

    init(filename: String = "blends.json") {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        fileURL = base.appendingPathComponent(filename)
        load()
    }

    // MARK: - Queries

    var isEmpty: Bool { blends.isEmpty }

    func saved(arc: Int, level: Int) -> SavedBlend? {
        blends.first { $0.arc == arc && $0.level == level }
    }

    // MARK: - Writing

    /// Keeping the same level twice replaces the earlier entry rather than
    /// stacking duplicates — replaying a board to get a cleaner solve should
    /// not litter the shelf.
    @discardableResult
    func keep(level: Int, arc: Int = 1, colours: [BlendColor]) -> SavedBlend {
        let blend = SavedBlend(arc: arc, level: level,
                               swatches: colours.map(\.hexString))
        blends.removeAll { $0.arc == arc && $0.level == level }
        blends.insert(blend, at: 0)
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

    // MARK: - Disk

    private struct Payload: Codable {
        var version: Int
        var blends: [SavedBlend]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        blends = payload.blends
        isReadOnly = payload.version > Self.currentVersion
    }

    private func save() {
        guard !isReadOnly else { return }
        let payload = Payload(version: Self.currentVersion, blends: blends)
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
