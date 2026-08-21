import SwiftUI

@MainActor
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            PigmentField(palette: router.backdropPalette)

            screen
                .id(router.current)
                .transition(.screen(forward: router.isMovingForward))
        }
        .animation(Motion.screen, value: router.current)
        .background(Theme.ground)
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

/// The header on every screen below the home screen.
///
/// Editorial rather than chrome: the control sits on its own line, the title is
/// set large and light underneath it with a tracked micro-cap above, and a
/// single hairline closes the block off. Nothing is boxed.
@MainActor
struct ScreenHeader: View {
    let title: String
    var eyebrow: String?
    var subtitle: String?
    var trailing: AnyView?
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            HStack(spacing: Theme.Space.snug) {
                IconButton(systemName: "arrow.left", label: "Back", action: onBack)
                Spacer(minLength: 0)
                if let trailing { trailing }
            }

            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    MoodLabel(eyebrow)
                }
                Text(title)
                    .font(Theme.display(34))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.text(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Hairline()
        }
        .padding(.horizontal, Theme.Space.margin)
        .padding(.top, Theme.Space.tight)
        .padding(.bottom, Theme.Space.base)
    }
}
