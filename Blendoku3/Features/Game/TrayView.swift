import SwiftUI

/// The pool of tiles waiting to be placed. Positions are fixed for the whole
/// level, so taking a tile leaves a gap rather than reshuffling everything
/// under the player's finger.
@MainActor
struct TrayView: View {
    let controller: GameController
    let settings: GameSettings
    let space: String
    var tileSize: CGFloat = 46

    private var session: GameSession { controller.session }

    var body: some View {
        FlowLayout(spacing: 10, rowSpacing: 10) {
            ForEach(session.trayOrder) { tile in
                slot(for: tile)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surface.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(controller.drag.hover == .tray
                                      ? Theme.accent.opacity(0.8) : Theme.hairline,
                                      lineWidth: controller.drag.hover == .tray ? 2 : 1)
                )
        )
        .animation(Motion.tile, value: controller.drag.hover)
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
                .overlay(
                    RoundedRectangle(cornerRadius: tileSize * Theme.tileCornerRatio, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2.5)
                        .opacity(controller.selected == tile ? 1 : 0)
                )
                .gesture(dragGesture(for: tile))
                .onTapGesture { controller.tap(tile: tile, from: .tray) }
                .transition(.popIn)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(tile.color.readableName) tile")
                .accessibilityHint("Double tap to pick up, then double tap a slot")
                .accessibilityAddTraits(.isButton)
        } else {
            RoundedRectangle(cornerRadius: tileSize * Theme.tileCornerRatio, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color.white.opacity(0.12))
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
