import Foundation
import Observation

/// Performs a song: its sound and its beat, started together.
///
/// One performer for the whole app, so there is only ever one song playing —
/// starting a keepsake while a board's replay is still ringing stops the
/// replay rather than layering two tunes.
@MainActor
@Observable
final class SongPerformer {
    static let shared = SongPerformer()

    /// What is playing, if anything. Screens compare it to their own id to
    /// know whether the playhead running across their ribbon is theirs.
    private(set) var playing: UUID?
    private(set) var startedAt: Date?
    private(set) var duration: Double = 0
    private(set) var schedule: SongSchedule?

    @ObservationIgnored private var token = 0
    @ObservationIgnored private var finish: Task<Void, Never>?

    private init() {}

    /// Composes the song off the main thread, then starts the sound and the
    /// beat in the same instant.
    ///
    /// Returns once the performance has begun, which is the moment a caller
    /// should start anything it wants to keep in time with it. Returns false
    /// if another performance, or a `stop`, arrived while this one was being
    /// composed.
    @discardableResult
    func perform(_ schedule: SongSchedule, warmth: Double, id: UUID = UUID()) async -> Bool {
        stop()
        token += 1
        let mine = token

        let audible = SoundField.shared.isLive
        let rate = SoundField.sampleRate
        var samples: [Float] = []
        if audible {
            samples = await Task.detached(priority: .userInitiated) {
                SongComposer.render(schedule, warmth: warmth, sampleRate: rate)
            }.value
        }
        guard mine == token else { return false }

        if audible { SoundField.shared.playSong(samples) }
        BeatPlayer.shared.play(schedule)

        playing = id
        startedAt = Date()
        duration = schedule.duration
        self.schedule = schedule
        finish = Task { [weak self] in
            try? await Task.sleep(for: .seconds(schedule.duration))
            guard !Task.isCancelled, let self, self.token == mine else { return }
            self.playing = nil
            self.schedule = nil
        }
        return true
    }

    func stop() {
        token += 1
        finish?.cancel()
        finish = nil
        SoundField.shared.stopSong()
        BeatPlayer.shared.stop()
        playing = nil
        schedule = nil
    }
}
