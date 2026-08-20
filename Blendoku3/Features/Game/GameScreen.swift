import SwiftUI

@MainActor
struct GameScreen: View {
    let level: Int

    static let space = "blendoku.game"

    @Environment(AppRouter.self) private var router
    @Environment(LevelCatalog.self) private var catalog
    @Environment(ProgressStore.self) private var progress
    @Environment(GameSettings.self) private var settings

    @State private var controller: GameController?
    @State private var showVictory = false
    @State private var record: LevelRecord?

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
        .overlay {
            if showVictory, let controller, let record {
                VictoryOverlay(puzzle: controller.session.puzzle,
                               record: record,
                               hasNextLevel: level < DifficultyCurve.levelCount,
                               onNext: { router.replaceTop(with: .game(level + 1)) },
                               onReplay: { replay(controller) },
                               onLevels: { router.replaceTop(with: .levels) })
                    .transition(.opacity)
            }
        }
        .task(id: level) { await load() }
    }

    // MARK: - Layout

    private func board(_ controller: GameController) -> some View {
        VStack(spacing: 0) {
            GameHUD(controller: controller,
                    onBack: { router.pop() },
                    onReset: { controller.reset() },
                    onHint: { controller.useHint() })

            BoardView(controller: controller, settings: settings, space: Self.space)
                .padding(.horizontal, Theme.Space.margin)
                .padding(.vertical, Theme.Space.base)
                .frame(maxHeight: .infinity)
                .modifier(Shake(trigger: controller.shakeToken))

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

    /// Tray tiles track the board's tile size so the two never look unrelated,
    /// but stay tappable on a crowded level.
    private func traySize(for controller: GameController) -> CGFloat {
        let count = controller.session.trayOrder.count
        return count > 12 ? 40 : (count > 8 ? 44 : 50)
    }

    // MARK: - Lifecycle

    private func load() async {
        let puzzle = await catalog.puzzle(for: level)
        controller = GameController(puzzle: puzzle)
        showVictory = false
        record = nil
        router.backdropPalette = puzzle.paletteSwatches(count: 4)
        progress.markPlayed(level: level)
        catalog.prefetch(after: level)
    }

    private func replay(_ controller: GameController) {
        withAnimation(Motion.screen) { showVictory = false }
        controller.reset()
        record = nil
    }

    private func finish(_ controller: GameController) {
        let session = controller.session
        controller.celebrate()

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

        Task {
            // Let the ripple finish crossing the board before covering it up.
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(Motion.screen) { showVictory = true }
        }
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
