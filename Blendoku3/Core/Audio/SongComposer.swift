import Foundation

/// Mixes a whole song into one buffer before a note of it plays.
///
/// The song is known in full the moment the board is solved, so it is rendered
/// ahead of time rather than performed live. That buys three things. Timing is
/// sample-exact rather than at the mercy of the main thread. Polyphony stops
/// being a problem — the climb puts twenty notes a second on top of each other,
/// which would exhaust any sensible pool of players, and here it is simply
/// addition. And the whole thing can be checked as arithmetic in a test: it
/// either clips or it does not.
///
/// Only thirteen pitches exist, so each voice is synthesised once per pitch and
/// then copied into place, which makes even the largest board's song cheap.
enum SongComposer {
    /// A safety net, not a mix setting. The voice gains are chosen so that no
    /// song comes near this — the worst case measured is under half of it —
    /// and a test holds them to that. If a future change ever does push a mix
    /// past it, the whole song is turned down evenly rather than clipped.
    static let ceiling: Float = 0.92

    private struct VoiceKey: Hashable {
        var event: Tuning.Event
        var step: Int
    }

    /// The song as mono samples at `sampleRate`, peak at most `ceiling`.
    static func render(_ schedule: SongSchedule, warmth: Double,
                       sampleRate: Double = 44_100) -> [Float] {
        guard schedule.duration > 0 else { return [] }

        var parts: [(event: Tuning.Event, note: SongSchedule.Note)] =
            schedule.melody.map { (event: .replay, note: $0) }
        for (index, note) in schedule.climb.enumerated() {
            parts.append((event: index == schedule.climb.count - 1 ? .crest : .climb, note: note))
        }

        var voices: [VoiceKey: [Float]] = [:]
        for part in parts {
            let key = VoiceKey(event: part.event, step: part.note.step)
            guard voices[key] == nil else { continue }
            voices[key] = ToneRenderer.render(
                Tuning.voice(step: key.step, event: key.event, warmth: warmth),
                sampleRate: sampleRate)
        }

        let frames = Int(((schedule.duration + 0.05) * sampleRate).rounded(.up))
        var mix = [Float](repeating: 0, count: max(frames, 1))
        mix.withUnsafeMutableBufferPointer { out in
            for part in parts {
                guard let samples = voices[VoiceKey(event: part.event, step: part.note.step)]
                else { continue }
                let start = max(0, Int((part.note.time * sampleRate).rounded()))
                guard start < out.count else { continue }
                let count = min(samples.count, out.count - start)
                samples.withUnsafeBufferPointer { source in
                    for index in 0..<count {
                        out[start + index] += source[index]
                    }
                }
            }
        }

        let loudest = peak(mix)
        if loudest > ceiling {
            let scale = ceiling / loudest
            for index in mix.indices { mix[index] *= scale }
        }
        return mix
    }

    static func peak(_ samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }
}
