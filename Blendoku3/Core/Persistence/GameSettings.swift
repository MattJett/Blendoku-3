import Foundation
import Observation
import SwiftUI

/// Which of the two grounds the app paints on.
///
/// Both are real designs rather than a tint flip: paper is a warm near-white
/// page and ink is a near-black one, and the puzzle colours read differently
/// against each. Following the system is the default because most people have
/// already made this choice once.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, paper, ink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .paper: "Paper"
        case .ink: "Ink"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .paper: return .light
        case .ink: return .dark
        }
    }
}

/// Player preferences. Deliberately few, and all of them accessibility-shaped.
@Observable
final class GameSettings {
    var hapticsEnabled = true
    /// The board's own voice: a tone per tile, pitched by its lightness.
    var soundEnabled = true
    /// Prints each tile's hex value on the tile — the colour-vision assist.
    var showColorValues = false
    /// Numbers the rows and columns so slots can be referred to out loud.
    var showGridLabels = false
    /// Paper, ink, or whatever the phone is already doing.
    var appearance: Appearance = .system
    /// Whether the first board's walkthrough has been dismissed. Persisted on
    /// its own rather than through `persist()`, because it is set by finishing
    /// the coaching rather than by a settings toggle.
    var hasFinishedCoaching = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        showColorValues = defaults.bool(forKey: Key.values)
        showGridLabels = defaults.bool(forKey: Key.labels)
        appearance = (defaults.string(forKey: Key.appearance)
            .flatMap(Appearance.init(rawValue:))) ?? .system
        hasFinishedCoaching = defaults.bool(forKey: Key.coaching)
    }

    func finishCoaching() {
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
        defaults.set(showColorValues, forKey: Key.values)
        defaults.set(showGridLabels, forKey: Key.labels)
        defaults.set(appearance.rawValue, forKey: Key.appearance)
    }

    private enum Key {
        static let haptics = "blendoku.haptics"
        static let sound = "swatchword.sound"
        static let values = "blendoku.values"
        static let labels = "blendoku.labels"
        static let appearance = "blendoku.appearance"
        static let coaching = "swatchword.coaching"
    }
}
