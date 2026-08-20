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

/// One coloured square. The same view draws clues, placed tiles and tray tiles.
///
/// Board tiles are deliberately bare — no border, no shadow, no highlight —
/// because every one of those draws a line between neighbours and turns a
/// gradient back into a row of swatches. Tray tiles keep the chip styling,
/// since there they really are separate objects.
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

    private var isChip: Bool { role == .tray || lifted }
    private var drawnSize: CGFloat { size + bleed * 2 }
    private var radius: CGFloat { size * Theme.tileCornerRatio }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: corners.contains(.topLeading) ? radius : 0,
            bottomLeadingRadius: corners.contains(.bottomLeading) ? radius : 0,
            bottomTrailingRadius: corners.contains(.bottomTrailing) ? radius : 0,
            topTrailingRadius: corners.contains(.topTrailing) ? radius : 0,
            style: .continuous)
    }

    var body: some View {
        shape
            .fill(Color(colour))
            .overlay(highlight)
            .overlay(border)
            .overlay(clueMark)
            .overlay(valueLabel)
            .frame(width: drawnSize, height: drawnSize)
            .compositingGroup()
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowOffset)
            .opacity(dimmed ? 0.35 : 1)
    }

    /// Only chips get the top-light. On the board it would draw a visible seam
    /// at every tile boundary.
    @ViewBuilder
    private var highlight: some View {
        if isChip {
            shape
                .fill(LinearGradient(colors: [.white.opacity(0.16), .clear],
                                     startPoint: .top, endPoint: .center))
                .blendMode(.plusLighter)
        }
    }

    @ViewBuilder
    private var border: some View {
        if isChip {
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
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

    private var shadowOpacity: Double {
        lifted ? 0.45 : (role == .tray ? 0.22 : 0)
    }

    private var shadowRadius: CGFloat {
        lifted ? 16 : (role == .tray ? 4 : 0)
    }

    private var shadowOffset: CGFloat {
        lifted ? 12 : (role == .tray ? 2 : 0)
    }
}

/// The hole a tile goes into.
///
/// Inset inside its cell rather than filling it, so the tiles around it still
/// meet the cell boundary and the shape reads as a solid band with a gap
/// punched out of it.
@MainActor
struct SlotView: View {
    var size: CGFloat
    var isHovered: Bool
    var isHinted: Bool

    private var inset: CGFloat { size * 0.10 }
    private var innerSize: CGFloat { size - inset * 2 }
    private var radius: CGFloat { innerSize * Theme.tileCornerRatio }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(isHovered ? 0.14 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: isHovered ? 2 : 1.2,
                                                     dash: isHovered ? [] : [4, 4]))
                    .foregroundStyle(isHovered ? Theme.accent : Color.white.opacity(0.24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.warning, lineWidth: 2)
                    .opacity(isHinted ? 1 : 0)
            )
            .frame(width: innerSize, height: innerSize)
            // Scaling the inset hole keeps the highlight inside its own cell,
            // so hovering never overlaps the tile next door.
            .scaleEffect(isHovered ? 1.1 : 1)
            .frame(width: size, height: size)
            .animation(Motion.tile, value: isHovered)
            .animation(Motion.tile, value: isHinted)
    }
}
