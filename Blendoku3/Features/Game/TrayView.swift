import SwiftUI

/// The pool of tiles waiting to be placed.
///
/// A shelf that runs the full width of the device and is rounded only along its
/// top edge, so it reads as the floor of the screen rather than as a card
/// parked near it. Positions are fixed for the whole level, so taking a tile
/// leaves a gap rather than reshuffling everything under the player's finger.
///
/// Each swatch is inlaid in a well rather than styled as a chip. That is what
/// lets the tile face stay the exact colour it will be on the board — the
/// separation a chip used to get from a border and a top-light now comes from
/// the shelf recessed around it, which never touches the colour being judged.
@MainActor
struct TrayView: View {
    let controller: GameController
    let settings: GameSettings
    let space: String
    var tileSize: CGFloat = 46

    private var session: GameSession { controller.session }
    private var isTarget: Bool { controller.drag.hover == .tray }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.panel,
                               bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0,
                               topTrailingRadius: Theme.Radius.panel,
                               style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack {
                MoodLabel("Tray", size: 9)
                Spacer(minLength: 0)
                Text("\(session.trayOrder.filter { session.isInTray($0) }.count)")
                    .font(Theme.mono(11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }

            FlowLayout(spacing: 7, rowSpacing: 7) {
                ForEach(session.trayOrder) { tile in
                    slot(for: tile)
                }
            }
        }
        .padding(.horizontal, Theme.Space.margin)
        .padding(.top, Theme.Space.base)
        .padding(.bottom, Theme.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // The shelf is the same colour as the page; what makes it a shelf
            // is the light along its top lip. A drop target washes the whole
            // surface rather than growing a border, so it never changes size
            // under the finger.
            SoftSurface(shape: shape, depth: 16,
                        glow: isTarget ? Theme.accent : nil)
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(Motion.quick, value: isTarget)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: TrayFrameKey.self,
                                       value: proxy.frame(in: .named(space)))
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { controller.returnSelectedToTray() }
        .accessibilityLabel("Tile tray")
    }

    /// The recess every swatch sits in, and the shape a taken one leaves behind.
    private var wellPad: CGFloat { 5 }
    private var wellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: (tileSize + wellPad * 2) * Theme.tileCornerRatio,
                         style: .continuous)
    }

    @ViewBuilder
    private func slot(for tile: Tile) -> some View {
        if session.isInTray(tile) {
            TileView(colour: tile.color, size: tileSize, role: .tray,
                     showValue: settings.showColorValues,
                     dimmed: controller.drag.payload?.tile == tile)
                .overlay(SelectionRing(size: tileSize, corners: .all,
                                       active: controller.selected == tile))
                .padding(wellPad)
                .softSurface(wellShape, depth: 6, pressed: true)
                .contentShape(wellShape)
                .gesture(dragGesture(for: tile))
                .onTapGesture { controller.tap(tile: tile, from: .tray) }
                .transition(.popIn)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(tile.color.readableName) tile")
                .accessibilityHint("Double tap to pick up, then double tap a slot")
                .accessibilityAddTraits(.isButton)
        } else {
            // The hole a taken tile left: the same well, now empty.
            SoftSurface(shape: wellShape, depth: 6, pressed: true)
                .frame(width: tileSize + wellPad * 2, height: tileSize + wellPad * 2)
                .accessibilityHidden(true)
        }
    }

    private func dragGesture(for tile: Tile) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(space))
            .onChanged { value in
                if controller.drag.payload == nil {
                    controller.beginDrag(tile: tile, from: .tray, size: tileSize,
                                         at: value.location)
                }
                controller.updateDrag(to: value.location)
            }
            .onEnded { value in controller.endDrag(at: value.location) }
    }
}
