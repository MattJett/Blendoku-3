import SwiftUI

@MainActor
struct LevelSelectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        GeometryReader { proxy in
            // One measurement for the whole screen. Every block is five
            // columns wide, so the swatch size falls straight out of it and
            // nothing downstream has to measure itself again.
            let side = (proxy.size.width - Theme.Space.margin * 2) / CGFloat(ChapterBlock.columns)

            VStack(spacing: 0) {
                ScreenHeader(title: "Levels",
                             eyebrow: "Progress",
                             subtitle: "\(progress.completedCount) of \(DifficultyCurve.levelCount) solved") {
                    router.pop()
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.wide) {
                        ForEach(Chapter.allCases) { chapter in
                            ChapterBlock(chapter: chapter, progress: progress, side: side) { level in
                                Haptics.play(.select)
                                router.push(.game(level))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.bottom, Theme.Space.vast)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            router.backdropPalette = DifficultyCurve.profile(for: progress.furthestUnlocked).previewRamp
        }
    }
}

/// One chapter: a label, a rule, and ten levels laid out as a single flush
/// block of colour.
///
/// The block is the point. Ten swatches meeting edge to edge is the same object
/// the board makes, so the level list looks like the game rather than like a
/// list of buttons that happen to be coloured.
@MainActor
private struct ChapterBlock: View {
    let chapter: Chapter
    let progress: ProgressStore
    let side: CGFloat
    let onPick: (Int) -> Void

    static let columns = 5

    private var levels: [Int] { Array(chapter.levels) }
    private var solved: Int { levels.filter { progress.isCompleted($0) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            header

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            let index = row * Self.columns + column
                            if index < levels.count {
                                LevelSwatch(level: levels[index],
                                            record: progress.record(for: levels[index]),
                                            unlocked: progress.isUnlocked(levels[index]),
                                            side: side,
                                            corners: corners(row: row, column: column)) {
                                    onPick(levels[index])
                                }
                            } else {
                                Color.clear.frame(width: side, height: side)
                            }
                        }
                    }
                }
            }
        }
    }

    private var rows: Int {
        Int((Double(levels.count) / Double(Self.columns)).rounded(.up))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.snug) {
            MoodLabel(String(format: "%02d", chapter.rawValue), tint: Theme.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(chapter.title)
                    .font(Theme.text(16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(chapter.subtitle)
                    .font(Theme.text(12))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
            Text("\(solved)/10")
                .font(Theme.mono(12))
                .monospacedDigit()
                .foregroundStyle(solved == 10 ? Theme.accent : Theme.textTertiary)
        }
    }

    /// A corner rounds only where both edges meeting there are on the outside
    /// of the block — the same rule the board uses.
    private func corners(row: Int, column: Int) -> TileCorners {
        var rounded: TileCorners = []
        let lastRow = rows - 1
        let lastColumn = Self.columns - 1
        if row == 0 && column == 0 { rounded.insert(.topLeading) }
        if row == 0 && column == lastColumn { rounded.insert(.topTrailing) }
        if row == lastRow && column == 0 { rounded.insert(.bottomLeading) }
        if row == lastRow && column == lastColumn { rounded.insert(.bottomTrailing) }
        return rounded
    }
}

/// One level in the block.
///
/// Unlocked levels carry their own generated ramp, so scrolling the list is
/// scrolling the hundred palettes the game will actually ask you to rebuild.
/// Locked ones drop back to the ground and read as holes in the matrix.
@MainActor
struct LevelSwatch: View {
    let level: Int
    let record: LevelRecord?
    let unlocked: Bool
    let side: CGFloat
    let corners: TileCorners
    let action: () -> Void

    private var ramp: [BlendColor] { DifficultyCurve.profile(for: level).previewRamp }
    private var radius: CGFloat { side * 0.20 }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: corners.contains(.topLeading) ? radius : 0,
            bottomLeadingRadius: corners.contains(.bottomLeading) ? radius : 0,
            bottomTrailingRadius: corners.contains(.bottomTrailing) ? radius : 0,
            topTrailingRadius: corners.contains(.topTrailing) ? radius : 0,
            style: .continuous)
    }

    private var ink: Color {
        unlocked ? (ramp.last ?? ramp[0]).readableForeground : Theme.textTertiary
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if unlocked {
                    shape.fill(
                        LinearGradient(colors: ramp.map { Color($0) },
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(Theme.sunken)
                    shape.strokeBorder(Theme.hairline, lineWidth: 1)
                }

                VStack(spacing: 4) {
                    Text("\(level)")
                        .font(Theme.mono(15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                    DotRow(count: record?.stars ?? 0, tint: ink)
                        .opacity(unlocked ? 1 : 0)
                }
            }
            // Drawn a half-point over its cell so neighbours overlap instead of
            // antialiasing against the page and leaving a seam down the block.
            // The outer frame stays exactly one cell, so the ten still add up
            // to the width the layout was given.
            .frame(width: side + 0.5, height: side + 0.5)
            .frame(width: side, height: side)
        }
        .buttonStyle(SwatchPressStyle())
        .disabled(!unlocked)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard unlocked else { return "Level \(level), locked" }
        guard let record else { return "Level \(level), not yet solved" }
        return "Level \(level), solved, \(record.stars) of 3 stars"
    }
}

/// Three dots instead of three stars. On a swatch the size of a fingernail a
/// star glyph turns to mush, and a dot keeps the block's geometry intact.
@MainActor
struct DotRow: View {
    let count: Int
    var tint: Color
    var size: CGFloat = 4
    /// Left nil when the surrounding swatch already announces the star count.
    var spokenLabel: String?

    var body: some View {
        HStack(spacing: size * 0.75) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint.opacity(index < count ? 0.95 : 0.22))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(spokenLabel == nil)
        .accessibilityLabel(spokenLabel ?? "")
    }
}

/// Flush swatches cannot scale on press — a growing tile would ride over its
/// neighbours and open the seam the block exists to close. So they brighten
/// instead.
@MainActor
struct SwatchPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.09 : 0)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}
