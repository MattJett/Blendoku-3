import Foundation
import Observation
import SwiftUI

/// Which of the two grounds the app paints on.
///
/// Both are real designs rather than a tint flip: light is a warm near-white
/// page and shadow is a near-black one, and the puzzle colours read
/// differently against each. Following the phone is the default because most
/// people have already made this choice once.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case light, shadow, system

    var id: String { rawValue }

    /// Reads a stored or requested value, including the names these grounds
    /// had before they were renamed. Choices are persisted by name, so without
    /// this anyone who had picked "ink" would silently find themselves back
    /// on the default.
    init?(stored: String) {
        switch stored.lowercased() {
        case "light", "paper": self = .light
        case "shadow", "ink", "dark": self = .shadow
        case "system", "auto": self = .system
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .light: "Light"
        case .shadow: "Shadow"
        case .system: "Auto"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .shadow: return .dark
        case .system: return nil
        }
    }
}

/// Player preferences. Deliberately few, and all of them accessibility-shaped.
@Observable
final class GameSettings {
    var hapticsEnabled = true
    /// The board's own voice: a tone per tile, pitched by its lightness.
    var soundEnabled = true
    /// A solved board plays itself back as a song before the result appears.
    var replayEnabled = true
    /// The song's pulse, felt through the phone. Separate from haptics as a
    /// whole: someone can want a tap when a tile lands and still not want the
    /// phone humming for ten seconds.
    var beatEnabled = true
    /// Prints each tile's hex value on the tile — the colour-vision assist.
    var showColorValues = false
    /// Adds each cell's row and column to what VoiceOver reads.
    var showGridLabels = true
    /// Light, shadow, or whatever the phone is already doing.
    var appearance: Appearance = .system
    /// Whether the first board's walkthrough has been dismissed. Persisted on
    /// its own rather than through `persist()`, because it is set by finishing
    /// the coaching rather than by a settings toggle.
    var hasFinishedCoaching = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = Storage.defaults) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        replayEnabled = defaults.object(forKey: Key.replay) as? Bool ?? true
        beatEnabled = defaults.object(forKey: Key.beat) as? Bool ?? true
        showColorValues = defaults.bool(forKey: Key.values)
        // On unless turned off: the board read positions out unconditionally
        // before this switch did anything, and nobody who relied on that
        // should lose it by updating.
        showGridLabels = defaults.object(forKey: Key.labels) as? Bool ?? true
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(stored:)) ?? .system
        hasFinishedCoaching = defaults.bool(forKey: Key.coaching)
    }

    func finishCoaching() {
        guard !hasFinishedCoaching else { return }
        hasFinishedCoaching = true
        defaults.set(true, forKey: Key.coaching)
    }

    func replayCoaching() {
        hasFinishedCoaching = false
        defaults.set(false, forKey: Key.coaching)
    }

    /// Called by the settings screen after a toggle changes.
    func persist() {
        defaults.set(hapticsEnabled, forKey: Key.haptics)
        defaults.set(soundEnabled, forKey: Key.sound)
        defaults.set(replayEnabled, forKey: Key.replay)
        defaults.set(beatEnabled, forKey: Key.beat)
        defaults.set(showColorValues, forKey: Key.values)
        defaults.set(showGridLabels, forKey: Key.labels)
        defaults.set(appearance.rawValue, forKey: Key.appearance)
    }

    private enum Key {
        static let haptics = "blendoku.haptics"
        static let sound = "swatchword.sound"
        static let replay = "swatchword.replay"
        static let beat = "swatchword.beat"
        static let values = "blendoku.values"
        static let labels = "blendoku.labels"
        static let appearance = "blendoku.appearance"
        static let coaching = "swatchword.coaching"
    }
}
