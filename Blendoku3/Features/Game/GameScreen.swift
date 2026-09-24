import SwiftUI

@MainActor
struct GameScreen: View {
    let level: Int

    static let space = "blendoku.game"

    /// What the screen is doing once a board is loaded.
    enum Stage: Equatable {
        case playing
        /// Solved; the board is playing its song back.
        case replaying
        case victory
    }

    @Environment(AppRouter.self) private var router
    @Environment(LevelCatalog.self) private var catalog
    @Environment(ProgressStore.self) private var progress
    @Environment(GameSettings.self) private var settings
    @Environment(SessionStore.self) private var sessions
    @Environment(\.scenePhase) private var scenePhase

    @State private var controller: GameController?
    @State private var stage: Stage = .playing
    @State private var record: LevelRecord?
    @State private var song: SongSchedule?
    /// The wait between solving and the result: the song, or the ripple.
    @State private var finale: Task<Void, Never>?
    /// The replay's own id with the performer, so the victory panel can tell
    /// its Listen button apart from it.
    @State private var replayID = UUID()

    var body: some View {
        ZStack {
            if let controller {
                board(controller)
                    .transition(.opacity)
            } else {
                LoadingBoard()
                    .transition(.opacity)
            }
        }
        .animation(Motion.screen, value: controller == nil)
        .coordinateSpace(.named(Self.space))
        .overlay { replayLayer }
        .overlay { pauseLayer }
        .overlay { victoryLayer }
        .task(id: level) { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { suspend() }
        }
        .onDisappear(perform: leave)
    }

    // MARK: - Layout

    private func board(_ controller: GameController) -> some View {
        VStack(spacing: 0) {
            GameHUD(controller: controller,
                    onPause: { pause(controller) },
                    onHint: { controller.useHint() })

            BoardView(controller: controller, settings: settings, space: Self.space)
                .padding(.horizontal, Theme.Space.margin)
                .padding(.vertical, Theme.Space.base)
                .frame(maxHeight: .infinity)
                .modifier(Shake(trigger: controller.shakeToken))

            // Above the tray rather than over it: every step the walkthrough
            // describes happens in the tray or on the board, and covering the
            // thing being explained is the usual way this sort of card fails.
            if isCoaching(controller) {
                CoachOverlay(step: coachStep(controller)) { settings.finishCoaching() }
                    .padding(.bottom, Theme.Space.snug)
            }

            // Flush to the bottom edge — the shelf is the floor of the screen,
            // not a card resting on it.
            TrayView(controller: controller, settings: settings, space: Self.space,
                     tileSize: traySize(for: controller))
        }
        .onPreferenceChange(BoardPlacementKey.self) { placement in
            Task { @MainActor in controller.drag.board = placement }
        }
        .onPreferenceChange(TrayFrameKey.self) { frame in
            Task { @MainActor in controller.drag.trayFrame = frame }
        }
        .overlay(alignment: .topLeading) { ghost(controller) }
        .onChange(of: controller.session.isSolved) { _, solved in
            guard solved else { return }
            finish(controller)
        }
        .onChange(of: controller.session.moves) { _, _ in
            remember(controller)
        }
    }

    @ViewBuilder
    private func ghost(_ controller: GameController) -> some View {
        if let payload = controller.drag.payload {
            TileView(colour: payload.tile.color,
                     size: payload.size * 1.14,
                     role: .placed,
                     showValue: settings.showColorValues,
                     lifted: true)
                .rotationEffect(.degrees(-2.5))
                .position(controller.drag.ghostCentre)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - Layers

    /// While the song plays: which pass it is on, and a tap anywhere to skip.
    @ViewBuilder
    private var replayLayer: some View {
        if stage == .replaying, let song {
            ReplayCaption(song: song, performer: SongPerformer.shared, onSkip: skipReplay)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var pauseLayer: some View {
        if let controller, controller.isPaused, stage == .playing {
            PauseOverlay(puzzle: controller.session.puzzle,
                         elapsed: controller.session.elapsed,
                         moves: controller.session.moves,
                         remaining: controller.session.remainingCount,
                         onResume: { withAnimation(Motion.screen) { controller.resume() } },
                         onRestart: { restart(controller) },
                         onHowToPlay: { leaveFor(.howToPlay, controller) },
                         onLevels: { remember(controller); router.showLevels() },
                         onHome: { remember(controller); router.popToRoot() })
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var victoryLayer: some View {
        if stage == .victory, let controller, let record, let song {
            let puzzle = controller.session.puzzle
            VictoryOverlay(puzzle: puzzle,
                           record: record,
                           song: song,
                           warmth: controller.warmth,
                           hasNextLevel: level < DifficultyCurve.levelCount,
                           arcComplete: progress.isArcComplete,
                           onNext: { router.replaceTop(with: .game(level + 1)) },
                           onFinishArc: { router.replaceTop(with: .arcComplete(puzzle.arc)) },
                           onRetry: { retry(controller) },
                           onArcs: { router.showArcs() },
                           onLevels: { router.showLevels() })
                .transition(.opacity)
        }
    }

    // MARK: - Coaching

    /// Only the very first board of the first arc, and only until it is either
    /// finished or skipped.
    private func isCoaching(_ controller: GameController) -> Bool {
        level == 1
            && controller.session.puzzle.arc == 1
            && !settings.hasFinishedCoaching
            && !controller.session.isSolved
    }

    /// Derived from what the player has actually done rather than from a step
    /// counter the card advances itself. The walkthrough cannot get ahead of
    /// them, and the last step is dismissed by solving the board rather than by
    /// tapping "done" on a description of solving the board.
    private func coachStep(_ controller: GameController) -> CoachOverlay.Step {
        let session = controller.session
        if !session.occupant.isEmpty { return .read }
        if controller.selected != nil || controller.drag.payload != nil { return .drop }
        return .pickUp
    }

    /// Tray tiles track the board's tile size so the two never look unrelated,
    /// but stay tappable on a crowded level. A shade smaller than the board's,
    /// because each one now carries a well around it — the recess is what
    /// separates the swatches, so the swatch itself no longer has to.
    private func traySize(for controller: GameController) -> CGFloat {
        let count = controller.session.trayOrder.count
        return count > 12 ? 38 : (count > 8 ? 42 : 46)
    }

    // MARK: - Lifecycle

    private func load() async {
        let puzzle = await catalog.puzzle(for: level)
        let profile = DifficultyCurve.profile(for: level, arc: puzzle.arc)
        let chroma = 0.16 * profile.chromaFraction.upperBound
        let made = GameController(puzzle: puzzle,
                                  warmth: Tuning.warmth(forHue: profile.baseHue, chroma: chroma))

        // Carry on where the player left off, if they left off here. A saved
        // board that does not fit this one exactly is thrown away rather than
        // half-applied.
        if let saved = sessions.snapshot(arc: puzzle.arc, level: level),
           !made.session.restore(saved) {
            sessions.clear()
        }

        controller = made
        stage = .playing
        record = nil
        song = nil
        router.backdropPalette = puzzle.paletteSwatches(count: 4)

        // The board picks the instrument, the tile picks the note — so the
        // whole tone table is rendered here, off the main thread, well before
        // anyone can touch a tile.
        SoundField.shared.prepare(hue: profile.baseHue, chroma: chroma)
        progress.markPlayed(level: level)
        catalog.prefetch(after: level)

        #if DEBUG
        applyPreviewHooks(made)
        #endif
    }

    #if DEBUG
    /// `-uiPreviewSolved 1` finishes the board on its own so the result can be
    /// photographed; `-uiPreviewPaused 1` opens the pause menu. Both run the
    /// real code path rather than faking the view, so the screenshot is of
    /// what the player gets.
    private func applyPreviewHooks(_ made: GameController) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "uiPreviewPaused") {
            made.pause()
        }
        if defaults.bool(forKey: "uiPreviewSolved") {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                made.session.solveCompletely()
            }
        }
    }

    private var previewSkipsReplay: Bool {
        UserDefaults.standard.string(forKey: "uiPreviewReplay") == "off"
    }
    #else
    private var previewSkipsReplay: Bool { false }
    #endif

    /// Saves the board as it stands, or forgets it if there is nothing worth
    /// coming back to.
    private func remember(_ controller: GameController) {
        let session = controller.session
        if session.isSolved || session.moves == 0 {
            if sessions.snapshot(arc: session.puzzle.arc, level: level) != nil { sessions.clear() }
        } else {
            sessions.save(session.snapshot())
        }
    }

    private func pause(_ controller: GameController) {
        Haptics.play(.select)
        withAnimation(Motion.screen) { controller.pause() }
        remember(controller)
    }

    /// The app is leaving the foreground. A board in play pauses, as every
    /// game does, so the player comes back to a menu rather than to a clock
    /// that kept running; a song in progress skips to its result, since
    /// nobody is there to hear the end of it.
    private func suspend() {
        guard let controller else { return }
        switch stage {
        case .playing:
            controller.pause()
            remember(controller)
        case .replaying:
            skipReplay()
        case .victory:
            break
        }
    }

    private func leave() {
        finale?.cancel()
        SongPerformer.shared.stop()
        if let controller { remember(controller) }
    }

    private func leaveFor(_ screen: AppRouter.Screen, _ controller: GameController) {
        remember(controller)
        router.push(screen)
    }

    private func restart(_ controller: GameController) {
        controller.reset()
        sessions.clear()
    }

    private func retry(_ controller: GameController) {
        SongPerformer.shared.stop()
        withAnimation(Motion.screen) { stage = .playing }
        controller.reset()
        record = nil
        song = nil
    }

    private func finish(_ controller: GameController) {
        let session = controller.session
        controller.celebrate()
        if level == 1 { settings.finishCoaching() }
        sessions.clear()

        let outcome = LevelRecord(level: level,
                                  moves: session.moves,
                                  seconds: session.elapsed,
                                  hintsUsed: session.hintsUsed,
                                  perfectMoves: session.puzzle.slots.count)
        record = outcome
        progress.complete(level: level,
                          moves: outcome.moves,
                          seconds: outcome.seconds,
                          hintsUsed: outcome.hintsUsed,
                          perfectMoves: outcome.perfectMoves)

        let schedule = controller.song()
        song = schedule
        let replays = settings.replayEnabled && !previewSkipsReplay

        finale?.cancel()
        finale = Task {
            // A breath after the last tile lands, so the solve itself is
            // heard before the song starts.
            try? await Task.sleep(for: .milliseconds(replays ? 650 : 950))
            guard !Task.isCancelled else { return }
            if replays {
                withAnimation(Motion.quick) { stage = .replaying }
                await SongPerformer.shared.perform(schedule, warmth: controller.warmth, id: replayID)
                guard !Task.isCancelled, stage == .replaying else { return }
                // The board lights from the instant the sound starts, not from
                // when it was asked for — composing the song takes a moment.
                controller.beginReplay(schedule)
                try? await Task.sleep(for: .seconds(schedule.lastOnset + 0.9))
                guard !Task.isCancelled, stage == .replaying else { return }
            }
            showVictory()
        }
    }

    private func skipReplay() {
        finale?.cancel()
        SongPerformer.shared.stop()
        showVictory()
    }

    private func showVictory() {
        controller?.endReplay()
        withAnimation(Motion.screen) { stage = .victory }
    }
}

/// Over the board while its song plays: which pass it is on, set small at the
/// foot of the screen, and the whole screen a tap target to skip.
@MainActor
private struct ReplayCaption: View {
    let song: SongSchedule
    let performer: SongPerformer
    let onSkip: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                HStack {
                    MonoLabel(passName(at: context.date), size: 10, tint: Theme.textSecondary,
                              weight: .semibold)
                    Spacer(minLength: 0)
                    MonoLabel("Tap to skip", size: 10)
                }
            }
            .padding(.horizontal, Theme.Space.margin)
            .padding(.vertical, Theme.Space.snug)
            .background(Theme.ground.opacity(0.92))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSkip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your board is playing its song")
        .accessibilityHint("Double tap to skip to the result")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("replay.skip")
    }

    private func passName(at date: Date) -> String {
        guard let startedAt = performer.startedAt else { return "Listening" }
        let seconds = date.timeIntervalSince(startedAt)
        return seconds < song.climbStart ? "01 — Your order" : "02 — The climb"
    }
}

/// Placeholder while a level is being generated. Generation takes a few tens of
/// milliseconds, but a blank screen for even that long looks broken.
@MainActor
private struct LoadingBoard: View {
    @State private var phase = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.textPrimary.opacity(phase ? 0.14 : 0.05))
                            .frame(width: 46, height: 46)
                            .animation(.easeInOut(duration: 0.9)
                                .repeatForever(autoreverses: true)
                                .delay(Double(row + column) * 0.08), value: phase)
                    }
                }
            }
        }
        .onAppear { phase = true }
        .accessibilityLabel("Building the level")
    }
}

/// One short shake, used when a tile is dropped somewhere it cannot go.
@MainActor
private struct Shake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-9, duration: 0.05)
                CubicKeyframe(8, duration: 0.07)
                CubicKeyframe(-5, duration: 0.07)
                CubicKeyframe(0, duration: 0.06)
            }
        }
    }
}
