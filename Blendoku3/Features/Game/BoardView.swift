import SwiftUI

/// Lays the puzzle out on a regular grid and hosts the tile gestures.
@MainActor
struct BoardView: View {
    let controller: GameController
    let settings: GameSettings
    let space: String

    private var puzzle: Puzzle { controller.session.puzzle }

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(columns: puzzle.columns, rows: puzzle.rows, available: proxy.size)

            ZStack(alignment: .topLeading) {
                ForEach(puzzle.cells, id: \.self) { point in
                    cell(at: point, metrics: metrics)
                        .position(metrics.centre(of: point))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .preference(key: BoardPlacementKey.self,
                        value: BoardPlacement(frame: proxy.frame(in: .named(space)),
                                              step: metrics.step,
                                              tile: metrics.tile,
                                              firstCentre: metrics.centre(of: GridPoint(0, 0))))
        }
    }

    // MARK: - One cell

    @ViewBuilder
    private func cell(at point: GridPoint, metrics: Metrics) -> some View {
        let session = controller.session
        let isHovered = controller.drag.hover == .slot(point)
        let dragged = controller.drag.payload?.tile

        Group {
            if puzzle.clues.contains(point), let colour = puzzle.solution[point] {
                TileView(colour: colour, size: metrics.tile, role: .clue,
                         showValue: settings.showColorValues)
            } else if let tile = session.tile(at: point) {
                TileView(colour: tile.color, size: metrics.tile, role: .placed,
                         showValue: settings.showColorValues,
                         dimmed: dragged == tile)
                    .overlay(selectionRing(for: tile, size: metrics.tile))
                    .gesture(dragGesture(for: tile, origin: .slot(point), size: metrics.tile))
                    .onTapGesture { controller.tap(tile: tile, from: .slot(point)) }
            } else {
                SlotView(size: metrics.tile,
                         isHovered: isHovered,
                         isHinted: controller.hinted == point)
                    .contentShape(Rectangle())
                    .onTapGesture { controller.tap(slot: point) }
            }
        }
        .modifier(LandingBounce(active: controller.landed == point, trigger: controller.landingToken))
        .modifier(SolveRipple(delay: rippleDelay(for: point),
                              radius: metrics.tile * Theme.tileCornerRatio,
                              trigger: controller.solveToken))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: point))
        .accessibilityAddTraits(session.tile(at: point) == nil && !puzzle.clues.contains(point)
                                ? [.isButton] : [])
    }

    @ViewBuilder
    private func selectionRing(for tile: Tile, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * Theme.tileCornerRatio, style: .continuous)
            .strokeBorder(Theme.accent, lineWidth: 2.5)
            .opacity(controller.selected == tile ? 1 : 0)
            .scaleEffect(controller.selected == tile ? 1 : 0.9)
            .animation(Motion.tile, value: controller.selected)
    }

    private func dragGesture(for tile: Tile, origin: DropTarget, size: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(space))
            .onChanged { value in
                if controller.drag.payload == nil {
                    controller.beginDrag(tile: tile, from: origin, size: size,
                                         at: value.location)
                }
                controller.updateDrag(to: value.location)
            }
            .onEnded { value in controller.endDrag(at: value.location) }
    }

    /// Ripples outward from the top-left of the board when it is solved.
    private func rippleDelay(for point: GridPoint) -> Double {
        Double(point.x + point.y) * 0.045
    }

    private func label(for point: GridPoint) -> String {
        let position = "row \(point.y + 1), column \(point.x + 1)"
        if puzzle.clues.contains(point), let colour = puzzle.solution[point] {
            return "\(colour.readableName), fixed, \(position)"
        }
        if let tile = controller.session.tile(at: point) {
            return "\(tile.color.readableName), \(position)"
        }
        return "Empty slot, \(position)"
    }

    // MARK: - Geometry

    struct Metrics {
        let tile: CGFloat
        let step: CGFloat
        let inset: CGPoint

        init(columns: Int, rows: Int, available: CGSize) {
            let gapRatio: CGFloat = 0.16
            let rawStep = min(available.width / CGFloat(max(columns, 1)),
                              available.height / CGFloat(max(rows, 1)))
            let clampedStep = min(max(rawStep, 22), 76)
            step = clampedStep
            tile = clampedStep * (1 - gapRatio)
            let boardWidth = CGFloat(columns) * step - (step - tile)
            let boardHeight = CGFloat(rows) * step - (step - tile)
            inset = CGPoint(x: (available.width - boardWidth) / 2 + tile / 2,
                            y: (available.height - boardHeight) / 2 + tile / 2)
        }

        func centre(of point: GridPoint) -> CGPoint {
            CGPoint(x: inset.x + CGFloat(point.x) * step,
                    y: inset.y + CGFloat(point.y) * step)
        }
    }
}

/// A short bounce when a tile lands in a slot.
@MainActor
private struct LandingBounce: ViewModifier {
    let active: Bool
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
            view.scaleEffect(active ? scale : 1)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.14, duration: 0.12, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.32, spring: .bouncy)
            }
        }
    }
}

/// The wave that runs across the board when the puzzle is finished.
@MainActor
private struct SolveRipple: ViewModifier {
    let delay: Double
    let radius: CGFloat
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, lift in
            view
                .scaleEffect(1 + lift * 0.18)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.white)
                        .opacity(lift * 0.32)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                )
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(0.0, duration: max(delay, 0.001))
                SpringKeyframe(1.0, duration: 0.18, spring: .snappy)
                SpringKeyframe(0.0, duration: 0.42, spring: .bouncy)
            }
        }
    }
}
