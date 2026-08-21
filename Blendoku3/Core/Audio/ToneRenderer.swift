import Foundation

/// Additive synthesis of one struck tone, as plain samples.
///
/// Deliberately free of AVFoundation so the sound can be reasoned about and
/// tested as arithmetic: given a spec, these are the numbers, and they either
/// clip or they do not.
///
/// The partials are those of a struck bowl rather than a plucked string —
/// slightly *inharmonic* (2.01x, 3.03x rather than 2x, 3x) and with the upper
/// ones dying away faster than the fundamental. That inharmonicity is what
/// stops it sounding like a synthesiser preset: real metal does not ring in
/// exact integer multiples, and the ear knows.
enum ToneRenderer {

    /// multiple of the fundamental, amplitude, how much faster it decays.
    static let partials: [(multiple: Double, amplitude: Double, decay: Double)] = [
        (1.00, 1.00, 1.00),
        (2.01, 0.42, 1.55),
        (3.03, 0.21, 2.30),
        (4.17, 0.11, 3.10),
    ]

    /// Every buffer is divided by the same number rather than normalised to its
    /// own peak.
    ///
    /// Per-buffer normalisation would make a wrong placement exactly as loud as
    /// a right one despite carrying twice the energy, flattening the very
    /// difference the sound exists to convey. This is the worst case the maths
    /// can produce — both voices, every partial, maximum warmth — so nothing
    /// clips and the quiet things stay quiet.
    static let headroom = 4.0

    static let attack = 0.018
    static let release = 0.05

    static func render(_ spec: ToneSpec, sampleRate: Double = 44_100) -> [Float] {
        let count = max(1, Int(sampleRate * spec.seconds))
        var samples = [Double](repeating: 0, count: count)

        var voices: [(frequency: Double, gain: Double)] = [(spec.frequency, 1.0)]
        if let companion = spec.companion {
            voices.append((companion, 0.85))
        }

        for voice in voices {
            for partial in partials {
                let frequency = voice.frequency * partial.multiple
                // Anything at or above Nyquist folds back as an alien tone.
                guard frequency < sampleRate * 0.45 else { continue }

                // Warmth thins or thickens everything above the fundamental,
                // leaving the pitch itself untouched.
                let colouring = partial.multiple == 1 ? 1.0 : (0.55 + 0.9 * spec.warmth)
                let amplitude = partial.amplitude * voice.gain * colouring
                let omega = 2 * .pi * frequency / sampleRate
                let fade = partial.decay / max(spec.decay, 0.01)

                for index in 0..<count {
                    let t = Double(index) / sampleRate
                    samples[index] += amplitude * exp(-t * fade) * sin(omega * Double(index))
                }
            }
        }

        // Both ends taper to exactly zero. A buffer that starts or stops on a
        // non-zero sample is a click, and a click is the least meditative sound
        // a speaker can make.
        let attackCount = min(count, Int(sampleRate * attack))
        if attackCount > 1 {
            for index in 0..<attackCount {
                samples[index] *= Double(index) / Double(attackCount)
            }
        }
        let releaseCount = min(count, Int(sampleRate * release))
        if releaseCount > 1 {
            for index in 0..<releaseCount {
                samples[count - 1 - index] *= Double(index) / Double(releaseCount)
            }
        }

        let scale = spec.gain / headroom
        return samples.map { Float($0 * scale) }
    }
}
