import SwiftUI

/// One coloured square. The same view draws clues, placed tiles and tray tiles;
/// only the trim changes, so a tile keeps its identity as it moves.
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
    var showValue = false
    var lifted = false
    var dimmed = false

    private var radius: CGFloat { size * Theme.tileCornerRatio }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(colour))
            .overlay(
                // A touch of top-light so flat colours still read as objects.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.16), .clear],
                                         startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)
            )
            .overlay(trim)
            .overlay(valueLabel)
            .frame(width: size, height: size)
            .compositingGroup()
            .shadow(color: .black.opacity(lifted ? 0.45 : 0.22),
                    radius: lifted ? 16 : 4,
                    x: 0, y: lifted ? 12 : 2)
            .opacity(dimmed ? 0.35 : 1)
    }

    @ViewBuilder
    private var trim: some View {
        switch role {
        case .clue:
            // Fixed tiles get a pinned inner ring so the eye can skip them.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .inset(by: size * 0.11)
                .strokeBorder(colour.readableForeground.opacity(0.30), lineWidth: max(1, size * 0.035))
        case .placed, .tray:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        if showValue {
            Text(colour.hexString.dropFirst())
                .font(Theme.mono(max(7, size * 0.20), weight: .semibold))
                .foregroundStyle(colour.readableForeground)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
    }
}

/// The dashed hole a tile has to go into.
@MainActor
struct SlotView: View {
    var size: CGFloat
    var isHovered: Bool
    var isHinted: Bool

    private var radius: CGFloat { size * Theme.tileCornerRatio }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(isHovered ? 0.13 : 0.045))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: isHovered ? 2 : 1.2,
                                                     dash: isHovered ? [] : [4, 4]))
                    .foregroundStyle(isHovered ? Theme.accent : Color.white.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.warning, lineWidth: 2)
                    .opacity(isHinted ? 1 : 0)
            )
            .frame(width: size, height: size)
            .scaleEffect(isHovered ? 1.09 : 1)
            .animation(Motion.tile, value: isHovered)
            .animation(Motion.tile, value: isHinted)
    }
}
