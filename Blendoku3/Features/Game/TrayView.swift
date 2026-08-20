import SwiftUI

/// The pool of tiles waiting to be placed.
///
/// A shelf that runs the full width of the device and is rounded only along its
/// top edge, so it reads as the floor of the screen rather than as a card
/// parked near it. Positions are fixed for the whole level, so taking a tile
/// leaves a gap rather than reshuffling everything under the player's finger.
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

            FlowLayout(spacing: 10, rowSpacing: 10) {
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
            shape
                .fill(Theme.raised)
                .overlay(alignment: .top) {
                    // A drop target lights its own edge rather than growing a
                    // border, so the shelf never changes size under the finger.
                    shape.strokeBorder(isTarget ? Theme.accent : Theme.hairline,
                                       lineWidth: isTarget ? 1.5 : 1)
                }
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

    @ViewBuilder
    private func slot(for tile: Tile) -> some View {
        if session.isInTray(tile) {
            TileView(colour: tile.color, size: tileSize, role: .tray,
                     showValue: settings.showColorValues,
                     dimmed: controller.drag.payload?.tile == tile)
                .overlay(SelectionRing(size: tileSize, corners: .all,
                                       active: controller.selected == tile))
                .gesture(dragGesture(for: tile))
                .onTapGesture { controller.tap(tile: tile, from: .tray) }
                .transition(.popIn)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(tile.color.readableName) tile")
                .accessibilityHint("Double tap to pick up, then double tap a slot")
                .accessibilityAddTraits(.isButton)
        } else {
            // The hole a taken tile left. A shallow well, not a dashed box.
            RoundedRectangle(cornerRadius: tileSize * Theme.tileCornerRatio, style: .continuous)
                .fill(Theme.sunken.opacity(0.7))
                .frame(width: tileSize, height: tileSize)
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
