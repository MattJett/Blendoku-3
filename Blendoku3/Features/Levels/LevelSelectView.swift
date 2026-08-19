import SwiftUI

@MainActor
struct LevelSelectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Levels",
                         subtitle: "\(progress.completedCount) of \(DifficultyCurve.levelCount) solved") {
                router.pop()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26, pinnedViews: [.sectionHeaders]) {
                    ForEach(Chapter.allCases) { chapter in
                        Section {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(chapter.levels), id: \.self) { level in
                                    LevelChip(level: level,
                                              record: progress.record(for: level),
                                              unlocked: progress.isUnlocked(level)) {
                                        Haptics.play(.select)
                                        router.push(.game(level))
                                    }
                                    .staggeredAppear(index: level - chapter.levels.lowerBound,
                                                     perItem: 0.012, travel: 10)
                                }
                            }
                            .padding(.horizontal, 20)
                        } header: {
                            ChapterHeader(chapter: chapter,
                                          solved: chapter.levels.filter { progress.isCompleted($0) }.count)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            router.backdropPalette = DifficultyCurve.profile(for: progress.furthestUnlocked).previewRamp
        }
    }
}

@MainActor
private struct ChapterHeader: View {
    let chapter: Chapter
    let solved: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(chapter.title)
                    .font(Theme.display(17))
                    .foregroundStyle(Theme.textPrimary)
                Text(chapter.subtitle)
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Text("\(solved)/10")
                .font(Theme.mono(12))
                .foregroundStyle(solved == 10 ? Theme.success : Theme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

/// One tile in the level grid: a miniature of the level's own palette, with
/// its stars underneath.
@MainActor
struct LevelChip: View {
    let level: Int
    let record: LevelRecord?
    let unlocked: Bool
    let action: () -> Void

    private var ramp: [BlendColor] { DifficultyCurve.profile(for: level).previewRamp }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(colors: ramp.map { Color($0) },
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .opacity(unlocked ? 1 : 0.18)
                        .saturation(unlocked ? 1 : 0.2)

                    if unlocked {
                        Text("\(level)")
                            .font(Theme.display(16, weight: .heavy))
                            .foregroundStyle((ramp.last ?? ramp[0]).readableForeground)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(record != nil ? Theme.success.opacity(0.7) : Theme.hairline,
                                      lineWidth: record != nil ? 1.5 : 1)
                )

                StarRow(count: record?.stars ?? 0)
                    .opacity(record == nil ? 0.22 : 1)
            }
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!unlocked)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard unlocked else { return "Level \(level), locked" }
        guard let record else { return "Level \(level), not yet solved" }
        return "Level \(level), solved, \(record.stars) of 3 stars"
    }
}

@MainActor
struct StarRow: View {
    let count: Int
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < count ? Theme.warning : Theme.textSecondary.opacity(0.5))
            }
        }
        .accessibilityHidden(true)
    }
}
