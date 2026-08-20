import SwiftUI

/// Which corners of a tile are rounded.
///
/// A tile on the board only rounds a corner where *both* of the edges meeting
/// there are exposed. So a run of five reads as one continuous bar with rounded
/// ends, and the colours inside it meet edge to edge with nothing between them —
/// which is the whole point of the game.
struct TileCorners: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let topLeading = TileCorners(rawValue: 1 << 0)
    static let topTrailing = TileCorners(rawValue: 1 << 1)
    static let bottomLeading = TileCorners(rawValue: 1 << 2)
    static let bottomTrailing = TileCorners(rawValue: 1 << 3)

    static let all: TileCorners = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
}

/// Builds the tile shape for a given corner set.
func tileShape(radius: CGFloat, corners: TileCorners) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(
        topLeadingRadius: corners.contains(.topLeading) ? radius : 0,
        bottomLeadingRadius: corners.contains(.bottomLeading) ? radius : 0,
        bottomTrailingRadius: corners.contains(.bottomTrailing) ? radius : 0,
        topTrailingRadius: corners.contains(.topTrailing) ? radius : 0,
        style: .continuous)
}

/// One coloured square. The same view draws clues, placed tiles and tray tiles.
///
/// **Nothing is ever painted on the face.** No border, no top-light, no inner
/// shading — in any role, anywhere in the app. On the board that is because
/// each of those draws a line between neighbours and turns a gradient back into
/// a row of swatches. In the tray it is because a tile there is a *promise*
/// about what the board will look like, and a 16% white top-light is a lie: it
/// lifts the swatch a visible step away from the colour that actually lands.
/// The tray reads the true colour now, so what you pick is what you get.
///
/// Depth still exists, it just lives outside the tile — the tray tile sits in a
/// well cut into the shelf, and a lifted tile throws a shadow onto the page.
/// Neither touches the pixels being judged.
@MainActor
struct TileView: View {
    enum Role {
        case clue      // given, cannot be moved
        case placed    // the player put it here
        case tray      // waiting to be used
    }

    let colour: BlendColor
    var size: CGFloat
    var role: Role = .placed
    var corners: TileCorners = .all
    var showValue = false
    var lifted = false
    var dimmed = false
    /// Grows the tile a hair past its cell so neighbours overlap rather than
    /// leaving a hairline of background where the blend should be seamless.
    var bleed: CGFloat = 0

    private var drawnSize: CGFloat { size + bleed * 2 }
    private var radius: CGFloat { size * Theme.tileCornerRatio }
    private var shape: UnevenRoundedRectangle { tileShape(radius: radius, corners: corners) }

    var body: some View {
        shape
            .fill(Color(colour))
            .overlay(clueMark)
            .overlay(valueLabel)
            .frame(width: drawnSize, height: drawnSize)
            .compositingGroup()
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
            // A tile in the air throws its own colour onto the page. Only ever
            // when lifted: on the board it would bleed into the neighbour and
            // corrupt the very comparison the player is making.
            .shadow(color: lifted ? Color(colour).opacity(0.55) : .clear,
                    radius: lifted ? size * 0.45 : 0)
            .opacity(dimmed ? 0.35 : 1)
    }

    /// Fixed tiles need to be tellable from placed ones, but an inner ring or a
    /// heavy outline would cut the gradient up again. A small corner dot sits
    /// out of the way of the colour the eye is actually reading.
    @ViewBuilder
    private var clueMark: some View {
        if role == .clue {
            Circle()
                .fill(colour.readableForeground.opacity(0.32))
                .frame(width: max(3, size * 0.09), height: max(3, size * 0.09))
                .padding(size * 0.13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        if showValue {
            Text(colour.hexString.dropFirst())
                .font(Theme.mono(max(7, size * 0.19), weight: .semibold))
                .foregroundStyle(colour.readableForeground)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
    }

    // A resting tile casts nothing, in either role. On the board a shadow would
    // fall across the neighbour it is being compared to; in the tray the well
    // behind it already carries the depth, and stacking a second shadow on top
    // would darken the swatch's own edges.
    private var shadowOpacity: Double { lifted ? 0.40 : 0 }
    private var shadowRadius: CGFloat { lifted ? 18 : 0 }
    private var shadowOffset: CGFloat { lifted ? 14 : 0 }
}

/// The ring that marks the picked-up tile.
///
/// Two strokes, one dark and one light, and no hue at all. A tinted ring is
/// unreadable against a tile that happens to share its hue — and on a board
/// where every tile is a different colour, that case comes up constantly. Depth
/// works on all of them.
@MainActor
struct SelectionRing: View {
    let size: CGFloat
    var corners: TileCorners = .all
    let active: Bool

    private var radius: CGFloat { size * Theme.tileCornerRatio }

    var body: some View {
        ZStack {
            tileShape(radius: radius, corners: corners)
                .strokeBorder(.black.opacity(0.55), lineWidth: 3.5)
            tileShape(radius: radius, corners: corners)
                .strokeBorder(.white.opacity(0.95), lineWidth: 1.5)
        }
        .opacity(active ? 1 : 0)
        .scaleEffect(active ? 1 : 0.92)
        .animation(Motion.tile, value: active)
        .allowsHitTesting(false)
    }
}

/// The hole a tile goes into. Literally a hole: the ground colour with its
/// lighting turned inward, so the empty cells read as pressed into the page
/// rather than as boxes drawn on top of it.
///
/// Inset inside its cell rather than filling it, so the tiles around it still
/// meet the cell boundary and the shape reads as a solid band with a gap
/// punched out of it.
@MainActor
struct SlotView: View {
    var size: CGFloat
    var isHovered: Bool
    var isHinted: Bool

    /// Soft UI trades contrast for calm, which is the wrong trade for someone
    /// who has asked the system for more of it. At increased contrast the wells
    /// get their outline back.
    @Environment(\.colorSchemeContrast) private var contrast

    private var inset: CGFloat { size * 0.10 }
    private var innerSize: CGFloat { size - inset * 2 }
    private var radius: CGFloat { innerSize * Theme.tileCornerRatio }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var glow: Color? {
        if isHovered { return Theme.accent }
        if isHinted { return Theme.accent }
        return nil
    }

    var body: some View {
        SoftSurface(shape: shape,
                    depth: max(4, size * 0.13),
                    pressed: true,
                    glow: glow)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(Theme.slotStroke, lineWidth: 1)
                }
            }
            .frame(width: innerSize, height: innerSize)
            // Scaling the inset hole keeps the highlight inside its own cell,
            // so hovering never overlaps the tile next door.
            .scaleEffect(isHovered ? 1.1 : 1)
            .frame(width: size, height: size)
            .animation(Motion.tile, value: isHovered)
            .animation(Motion.tile, value: isHinted)
    }
}
