import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Plays the board.
///
/// Thin wrapper in the same shape as `Haptics`, for the same reason: views
/// never talk to AVFoundation, and one switch in Settings turns all of it off.
///
/// Tones are rendered as samples rather than shipped as files. A hundred levels
/// times thirteen pitches times three events is four thousand sounds nobody
/// wants to author, store or download — and they would all be approximations of
/// something the app can work out exactly.
@MainActor
final class SoundField {
    static let shared = SoundField()

    var isEnabled = true

    /// Whether a note asked for now would actually sound.
    var isLive: Bool { isEnabled && !Runtime.isSilent }

    #if canImport(AVFoundation)
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    /// The finished board's song gets a player of its own, so a tap on the
    /// victory panel can never cut it off halfway.
    private let songPlayer = AVAudioPlayerNode()
    private var nextPlayer = 0
    private var wired = false
    /// Whether the audio session is configured and active. Checked on every
    /// note but *set* only when it has to be: configuring a session is a
    /// round trip to the audio server, and it used to happen on every tap.
    private var sessionReady = false

    private struct Key: Hashable {
        var step: Int
        var event: Tuning.Event
    }

    private var buffers: [Key: AVAudioPCMBuffer] = [:]
    /// Bumped whenever a new level asks for a table, so a slow render for the
    /// level you just left cannot overwrite the one you are on.
    private var generation = 0
    private let renderQueue = DispatchQueue(label: "swatchword.tones", qos: .utility)

    static let sampleRate = 44_100.0
    /// Enough for two quick hands. The song no longer draws on this pool —
    /// it is one pre-mixed buffer on a player of its own.
    private static let voices = 8

    private var format: AVAudioFormat? {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: Self.sampleRate,
                      channels: 1,
                      interleaved: false)
    }
    #endif

    private init() {
        #if canImport(AVFoundation)
        let centre = NotificationCenter.default
        // An interruption — a call, Siri, another app claiming the session —
        // deactivates ours without asking. Forget it was ready, so the next
        // note sets it up again instead of playing into nothing.
        centre.addObserver(forName: AVAudioSession.interruptionNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sessionReady = false }
        }
        centre.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sessionReady = false
                self?.wired = false
            }
        }
        #endif
    }

    // MARK: - Level

    /// Renders this level's voice.
    ///
    /// The board picks the instrument and the tile picks the note, so the whole
    /// table can be built once when a level opens — off the main thread, well
    /// before anyone touches a tile — instead of synthesising during a gesture.
    func prepare(hue: Double, chroma: Double) {
        #if canImport(AVFoundation)
        let warmth = Tuning.warmth(forHue: hue, chroma: chroma)
        generation += 1
        let token = generation
        let events: [Tuning.Event] = [.pickUp, .settled, .unsettled]

        renderQueue.async { [weak self] in
            var built: [Key: [Float]] = [:]
            for step in 0..<Tuning.steps {
                for event in events {
                    let spec = Tuning.voice(step: step, event: event, warmth: warmth)
                    built[Key(step: step, event: event)] =
                        ToneRenderer.render(spec, sampleRate: Self.sampleRate)
                }
            }
            Task { @MainActor in self?.install(built, token: token) }
        }
        #endif
    }

    // MARK: - Playing

    func play(_ event: Tuning.Event, for colour: BlendColor) {
        #if canImport(AVFoundation)
        guard isLive else { return }
        let key = Key(step: Tuning.step(for: colour), event: event)
        guard let buffer = buffers[key], start(), !players.isEmpty else { return }

        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        // Stopping first frees the node if it is still ringing from an earlier
        // tap; the pool is plenty for two hands but a fast player can lap it.
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
        #endif
    }

    /// Plays a pre-mixed song from the top. Returns whether it is sounding.
    @discardableResult
    func playSong(_ samples: [Float]) -> Bool {
        #if canImport(AVFoundation)
        guard isLive, !samples.isEmpty, let format, start(),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return false }
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        songPlayer.stop()
        songPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        songPlayer.play()
        return true
        #else
        return false
        #endif
    }

    func stopSong() {
        #if canImport(AVFoundation)
        songPlayer.stop()
        #endif
    }

    // MARK: - Engine

    #if canImport(AVFoundation)
    private func install(_ built: [Key: [Float]], token: Int) {
        guard token == generation, let format else { return }
        var made: [Key: AVAudioPCMBuffer] = [:]
        for (key, samples) in built {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buffer.floatChannelData?[0] else { continue }
            samples.withUnsafeBufferPointer { source in
                guard let base = source.baseAddress else { return }
                channel.update(from: base, count: samples.count)
            }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            made[key] = buffer
        }
        buffers = made
    }

    @discardableResult
    private func start() -> Bool {
        if !sessionReady {
            // `.ambient` on purpose: this game must never stop whatever the
            // player already had playing, and it should go quiet with the
            // ringer switch. A meditation app that hijacks your music is not a
            // meditation app.
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                sessionReady = true
            } catch {
                return false
            }
        }

        if !wired, let format {
            if players.isEmpty {
                for _ in 0..<Self.voices {
                    let player = AVAudioPlayerNode()
                    engine.attach(player)
                    players.append(player)
                }
                engine.attach(songPlayer)
            }
            for player in players {
                engine.connect(player, to: engine.mainMixerNode, format: format)
            }
            engine.connect(songPlayer, to: engine.mainMixerNode, format: format)
            // Soft by default. The tones are already quiet; this is the room
            // they are quiet in.
            engine.mainMixerNode.outputVolume = 0.55
            wired = true
        }

        // Restarted rather than assumed: an interruption stops the engine,
        // and nothing tells us.
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return engine.isRunning
    }
    #endif
}
