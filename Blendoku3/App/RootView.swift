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
        case .title:
            TitleView()
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
        case .keepsakes:
            KeepsakesView()
        case .chromarcs:
            ChromarcSelectView()
        case .arcComplete(let arc):
            ArcCompleteView(arc: Chromarc.numbered(arc))
        }
    }
}

/// The header on every screen below Home.
///
/// A back slab on its own line, then the title cut into the page with a mono
/// annotation above it. Nothing is boxed: the title is not a control, so it
/// does not stand up.
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
                    .accessibilityIdentifier("screen.back")
                Spacer(minLength: 0)
                if let trailing { trailing }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    MonoLabel(eyebrow)
                }
                Text(title)
                    .font(Theme.display(40))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .carved()
                    .accessibilityAddTraits(.isHeader)
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
