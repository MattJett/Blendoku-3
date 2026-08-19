#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper so views never talk to UIKit directly and every call can be
/// switched off from settings in one place.
@MainActor
enum Haptics {
    static var isEnabled = true

    enum Tap {
        case pickUp, drop, snap, reject, select
    }

    static func play(_ tap: Tap) {
        guard isEnabled else { return }
        #if canImport(UIKit)
        switch tap {
        case .pickUp:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.7)
        case .drop:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        case .snap:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .reject:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .select:
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #endif
    }

    static func celebrate() {
        guard isEnabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
