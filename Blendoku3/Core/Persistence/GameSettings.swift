import Foundation
import Observation

/// Player preferences. Deliberately few, and all of them accessibility-shaped.
@Observable
final class GameSettings {
    var hapticsEnabled = true
    /// Prints each tile's hex value on the tile — the colour-vision assist.
    var showColorValues = false
    /// Numbers the rows and columns so slots can be referred to out loud.
    var showGridLabels = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        showColorValues = defaults.bool(forKey: Key.values)
        showGridLabels = defaults.bool(forKey: Key.labels)
    }

    /// Called by the settings screen after a toggle changes.
    func persist() {
        defaults.set(hapticsEnabled, forKey: Key.haptics)
        defaults.set(showColorValues, forKey: Key.values)
        defaults.set(showGridLabels, forKey: Key.labels)
    }

    private enum Key {
        static let haptics = "blendoku.haptics"
        static let values = "blendoku.values"
        static let labels = "blendoku.labels"
    }
}
