#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Thin wrapper so views never talk to UIKit directly and every call can be
/// switched off from settings in one place.
@MainActor
enum Haptics {
    static var isEnabled = true

    enum Tap {
        case pickUp, drop, snap, reject, select
    }

    private static var live: Bool { isEnabled && !Runtime.isSilent }

    #if canImport(UIKit)
    // Kept rather than made per tap. A generator made on demand has to spin
    // the Taptic Engine up first, which is where the latency on a fast drag
    // came from.
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()
    #endif

    static func play(_ tap: Tap) {
        guard live else { return }
        #if canImport(UIKit)
        switch tap {
        case .pickUp:
            light.impactOccurred(intensity: 0.7)
            medium.prepare()
        case .drop:
            medium.impactOccurred(intensity: 0.8)
        case .snap:
            rigid.impactOccurred()
        case .reject:
            notice.notificationOccurred(.warning)
        case .select:
            selection.selectionChanged()
        }
        #endif
    }

    static func celebrate() {
        guard live else { return }
        #if canImport(UIKit)
        notice.notificationOccurred(.success)
        #endif
    }
}

/// Plays a song's beat through the Taptic Engine.
///
/// Core Haptics rather than the feedback generators, because the beat has to
/// land *on time*: the whole pattern is handed to the engine at once and the
/// engine schedules it, so it cannot drift against the audio the way a chain
/// of timers on the main thread would. Phones without a Taptic Engine, and the
/// simulator, get silence rather than an error.
@MainActor
final class BeatPlayer {
    static let shared = BeatPlayer()

    var isEnabled = true

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    #endif

    private init() {}

    func play(_ schedule: SongSchedule) {
        stop()
        guard isEnabled, Haptics.isEnabled, !Runtime.isSilent else { return }
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = readyEngine() else { return }
        do {
            let pattern = try Self.pattern(for: BeatScore.events(for: schedule))
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
        } catch {
            self.player = nil
        }
        #endif
    }

    func stop() {
        #if canImport(CoreHaptics)
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        #endif
    }

    #if canImport(CoreHaptics)
    private func readyEngine() -> CHHapticEngine? {
        if engine == nil {
            guard let made = try? CHHapticEngine() else { return nil }
            made.playsHapticsOnly = true
            made.isAutoShutdownEnabled = true
            // The system can stop the engine at any time — a call, the app
            // going to the background. Dropping it means the next song makes
            // a fresh one instead of talking to a dead engine.
            made.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engine = nil; self?.player = nil }
            }
            made.resetHandler = { [weak self] in
                Task { @MainActor in self?.engine = nil; self?.player = nil }
            }
            engine = made
        }
        do {
            try engine?.start()
        } catch {
            engine = nil
        }
        return engine
    }

    private static func pattern(for events: [BeatScore.Event]) throws -> CHHapticPattern {
        var haptics: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []

        for event in events {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                   value: Float(event.intensity))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                   value: Float(event.sharpness))
            switch event.kind {
            case .tap:
                haptics.append(CHHapticEvent(eventType: .hapticTransient,
                                             parameters: [intensity, sharpness],
                                             relativeTime: event.time))
            case .swell:
                haptics.append(CHHapticEvent(eventType: .hapticContinuous,
                                             parameters: [intensity, sharpness],
                                             relativeTime: event.time,
                                             duration: event.duration))
                // The hum rises under the climb rather than arriving at full
                // strength, so the run is felt as a lift.
                curves.append(CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0, value: Float(event.rampFrom)),
                        .init(relativeTime: event.duration, value: 1),
                    ],
                    relativeTime: event.time))
            }
        }
        return try CHHapticPattern(events: haptics, parameterCurves: curves)
    }
    #endif
}
