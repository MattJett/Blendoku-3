import SwiftUI

/// Offsetting a pan by a drag translation. Swift does not ship arithmetic on
/// `CGSize`, and spelling it out at all four call sites obscures what is a very
/// simple idea.
private func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

/// Lays the puzzle out on a regular grid and hosts the tile gestures.
@MainActor
struct BoardView: View {
    let controller: GameController
    let settings: GameSettings
    let space: String

    private var puzzle: Puzzle { controller.session.puzzle }

    /// Zoom and pan are applied to the *layout*, not as a `scaleEffect` over
    /// it. A transform would leave `BoardPlacement` describing the untransformed
    /// board, and every drop would land in the wrong cell; folding the zoom into
    /// `step` and the pan into `inset` means the geometry the drag coordinator
    /// reads is the geometry on screen, with nothing to keep in sync.
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var sweep: CGSize = .zero

    private static let maxZoom: CGFloat = 3.2

    var body: some View {
        GeometryReader { proxy in
            let live = min(max(zoom * pinch, 1), Self.maxZoom)
            let metrics = Metrics(columns: puzzle.columns, rows: puzzle.rows,
                                  available: proxy.size, zoom: live,
                                  pan: clamped(pan + sweep, zoom: live,
                                               available: proxy.size))

            let occupied = Set(puzzle.cells)

            ZStack(alignment: .topLeading) {
                ForEach(puzzle.cells, id: \.self) { point in
                    cell(at: point, metrics: metrics, occupied: occupied)
                        .position(metrics.centre(of: point))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay { BoardMarks(metrics: metrics, columns: puzzle.columns, rows: puzzle.rows) }
            // Behind the tiles rather than over them, so a drag that starts on a
            // tile is claimed by the tile and only a drag on bare board pans.
            .background(Color.clear.contentShape(Rectangle()))
            .gesture(panGesture(available: proxy.size))
            .simultaneousGesture(zoomGesture())
            .onTapGesture(count: 2) {
                withAnimation(Motion.screen) { zoom = 1; pan = .zero }
            }
            .clipped()
            .preference(key: BoardPlacementKey.self,
                        value: BoardPlacement(frame: proxy.frame(in: .named(space)),
                                              step: metrics.step,
                                              tile: metrics.tile,
                                              firstCentre: metrics.centre(of: GridPoint(0, 0))))
        }
    }

    // MARK: - Zoom and pan

    private func zoomGesture() -> some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                zoom = min(max(zoom * value.magnification, 1), Self.maxZoom)
                if zoom == 1 { withAnimation(Motion.tile) { pan = .zero } }
            }
    }

    /// Only pans once there is something to pan to. At fit size the board is
    /// fully visible, so a drag across it would just slide it off the screen.
    private func panGesture(available: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($sweep) { value, state, _ in state = value.translation }
            .onEnded { value in
                pan = clamped(pan + value.translation, zoom: zoom, available: available)
            }
    }

    /// Keeps the board from being dragged away from the player. The allowance is
    /// exactly the overhang the zoom created, so at fit size it is zero.
    private func clamped(_ offset: CGSize, zoom: CGFloat, available: CGSize) -> CGSize {
        let base = Metrics.baseStep(columns: puzzle.columns, rows: puzzle.rows, available: available)
        let width = CGFloat(puzzle.columns) * base * zoom
        let height = CGFloat(puzzle.rows) * base * zoom
        let slackX = max(0, (width - available.width) / 2)
        let slackY = max(0, (height - available.height) / 2)
        return CGSize(width: min(max(offset.width, -slackX), slackX),
                      height: min(max(offset.height, -slackY), slackY))
    }

    // MARK: - One cell

    @ViewBuilder
    private func cell(at point: GridPoint, metrics: Metrics,
                      occupied: Set<GridPoint>) -> some View {
        let session = controller.session
        let isHovered = controller.drag.hover == .slot(point)
        let dragged = controller.drag.payload?.tile
        let corners = Self.corners(at: point, in: occupied)

        Group {
            if puzzle.clues.contains(point), let colour = puzzle.solution[point] {
                TileView(colour: colour, size: metrics.tile, role: .clue,
                         corners: corners, showValue: settings.showColorValues,
                         bleed: metrics.bleed)
            } else if let tile = session.tile(at: point) {
                TileView(colour: tile.color, size: metrics.tile, role: .placed,
                         corners: corners, showValue: settings.showColorValues,
                         dimmed: dragged == tile, bleed: metrics.bleed)
                    .overlay(SelectionRing(size: metrics.tile, corners: corners,
                                           active: controller.selected == tile))
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
        .modifier(LandingFlash(active: controller.landed == point, trigger: controller.landingToken))
        .modifier(SolveRipple(delay: rippleDelay(for: point),
                              trigger: controller.solveToken))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: point))
        .accessibilityAddTraits(session.tile(at: point) == nil && !puzzle.clues.contains(point)
                                ? [.isButton] : [])
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

    /// A corner is rounded only where both of its edges are exposed, which is
    /// what makes a run of tiles read as a single bar instead of a row of chips.
    static func corners(at point: GridPoint, in occupied: Set<GridPoint>) -> TileCorners {
        let up = occupied.contains(point.offset(dx: 0, dy: -1))
        let down = occupied.contains(point.offset(dx: 0, dy: 1))
        let left = occupied.contains(point.offset(dx: -1, dy: 0))
        let right = occupied.contains(point.offset(dx: 1, dy: 0))

        var rounded: TileCorners = []
        if !up && !left { rounded.insert(.topLeading) }
        if !up && !right { rounded.insert(.topTrailing) }
        if !down && !left { rounded.insert(.bottomLeading) }
        if !down && !right { rounded.insert(.bottomTrailing) }
        return rounded
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

        /// Half a point of overlap between neighbours. Without it, two tiles
        /// that share an edge land on a fractional pixel and antialias against
        /// the background, leaving a hairline seam down the middle of a blend.
        let bleed: CGFloat = 0.5

        /// The size a cell gets when the whole board has to fit the screen.
        /// The floor matters now that boards reach fourteen rows: below it the
        /// tiles stop being touchable, and zoom is the answer rather than
        /// shrinking further.
        static func baseStep(columns: Int, rows: Int, available: CGSize) -> CGFloat {
            let raw = min(available.width / CGFloat(max(columns, 1)),
                          available.height / CGFloat(max(rows, 1)))
            return min(max(raw, 26), 92)
        }

        init(columns: Int, rows: Int, available: CGSize,
             zoom: CGFloat = 1, pan: CGSize = .zero) {
            step = Self.baseStep(columns: columns, rows: rows, available: available) * zoom
            // No gap: cells in the same shape are meant to touch, and separate
            // shapes are already kept a clear cell apart by the generator.
            tile = step
            let boardWidth = CGFloat(columns) * step
            let boardHeight = CGFloat(rows) * step
            inset = CGPoint(x: (available.width - boardWidth) / 2 + tile / 2 + pan.width,
                            y: (available.height - boardHeight) / 2 + tile / 2 + pan.height)
        }

        func centre(of point: GridPoint) -> CGPoint {
            CGPoint(x: inset.x + CGFloat(point.x) * step,
                    y: inset.y + CGFloat(point.y) * step)
        }
    }
}

/// A brief lift in brightness when a tile lands in a slot.
///
/// Deliberately not a scale: a tile that grows would ride over the ones beside
/// it, and the whole point is that neighbours meet exactly.
@MainActor
private struct LandingFlash: ViewModifier {
    let active: Bool
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, glow in
            view.brightness(active ? glow * 0.22 : 0)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.0, duration: 0.10, spring: .snappy)
                SpringKeyframe(0.0, duration: 0.38, spring: .smooth)
            }
        }
    }
}

/// The wave that runs across the board when the puzzle is finished — a band of
/// light travelling along the finished blend rather than tiles popping, which
/// would break the very continuity the player just earned.
@MainActor
private struct SolveRipple: ViewModifier {
    let delay: Double
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, lift in
            view
                .brightness(lift * 0.30)
                .saturation(1 + lift * 0.35)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(0.0, duration: max(delay, 0.001))
                SpringKeyframe(1.0, duration: 0.18, spring: .snappy)
                SpringKeyframe(0.0, duration: 0.44, spring: .smooth)
            }
        }
    }
}


/// Four crosshairs at the corners of the grid.
///
/// The board needs to feel placed on the page rather than floating in the
/// middle of it, but a box around it would add a second rectangle competing
/// with the tiles. Registration marks — the moodboard's technical-drawing
/// idiom — locate it with four hairlines and no enclosure.
@MainActor
private struct BoardMarks: View {
    let metrics: BoardView.Metrics
    let columns: Int
    let rows: Int

    private let gap: CGFloat = 12

    var body: some View {
        let first = metrics.centre(of: GridPoint(0, 0))
        let last = metrics.centre(of: GridPoint(columns - 1, rows - 1))
        let half = metrics.tile / 2
        let left = first.x - half - gap
        let right = last.x + half + gap
        let top = first.y - half - gap
        let bottom = last.y + half + gap

        ZStack {
            RegistrationMark().position(x: left, y: top)
            RegistrationMark().position(x: right, y: top)
            RegistrationMark().position(x: left, y: bottom)
            RegistrationMark().position(x: right, y: bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
