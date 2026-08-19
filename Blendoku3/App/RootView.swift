import SwiftUI

@MainActor
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            AuroraBackground(palette: router.backdropPalette)

            screen
                .id(router.current)
                .transition(.screen(forward: router.isMovingForward))
        }
        .animation(Motion.screen, value: router.current)
        .background(Theme.backdrop)
    }

    @ViewBuilder
    private var screen: some View {
        switch router.current {
        case .home:
            HomeView()
        case .levels:
            LevelSelectView()
        case .game(let level):
            GameScreen(level: level)
        case .howToPlay:
            HowToPlayView()
        case .settings:
            SettingsView()
        }
    }
}

/// Header shared by the secondary screens: a back chevron and a title.
@MainActor
struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CircleIconButton(systemName: "chevron.left", label: "Back", action: onBack)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.display(13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 0)

            if let trailing { trailing }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
