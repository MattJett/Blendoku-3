import Foundation

/// A tiny deterministic generator so every level is identical on every device
/// and every launch. `SystemRandomNumberGenerator` would not be reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform double in 0..<1.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    mutating func nextBool(probability: Double) -> Bool {
        nextUnit() < probability
    }

    mutating func pick<T>(_ elements: [T]) -> T {
        elements[nextInt(in: 0...(elements.count - 1))]
    }

    mutating func shuffled<T>(_ elements: [T]) -> [T] {
        var result = elements
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let swapIndex = nextInt(in: 0...index)
            result.swapAt(index, swapIndex)
        }
        return result
    }
}

extension UInt64 {
    /// Stable mixing so `arc`, `level` and `attempt` produce unrelated streams.
    ///
    /// Arc 1 is deliberately a no-op rather than "just another value mixed in".
    /// The first hundred levels are the ones people have played, and folding an
    /// arc term into their seed — even a constant one — would silently rebuild
    /// every board in the game. Chromarc 1 is byte-identical to what existed
    /// before arcs did, and there is a test that says so.
    static func gameSeed(arc: Int = 1, level: Int, salt: UInt64) -> UInt64 {
        var value = UInt64(bitPattern: Int64(level)) &* 0x9E3779B97F4A7C15
        value ^= salt &* 0xC2B2AE3D27D4EB4F
        if arc != 1 {
            value ^= UInt64(bitPattern: Int64(arc)) &* 0x94D049BB133111EB
        }
        value = (value ^ (value >> 29)) &* 0xBF58476D1CE4E5B9
        return value ^ (value >> 32)
    }
}
