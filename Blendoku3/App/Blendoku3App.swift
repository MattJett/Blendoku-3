import SwiftUI

@main
@MainActor
struct Blendoku3App: App {
    @State private var router: AppRouter
    @State private var catalog = LevelCatalog()
    @State private var progress = ProgressStore()
    @State private var settings = GameSettings()
    @State private var library = BlendLibrary()
    @State private var sessions = SessionStore()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        _router = State(initialValue: AppRouter(stack: Self.launchStack()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(catalog)
                .environment(progress)
                .environment(settings)
                .environment(library)
                .environment(sessions)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onAppear {
                    applyFeedbackSettings()
                    applyLaunchOverrides()
                }
                .onChange(of: settings.hapticsEnabled) { _, _ in applyFeedbackSettings() }
                .onChange(of: settings.soundEnabled) { _, _ in applyFeedbackSettings() }
                .onChange(of: settings.beatEnabled) { _, _ in applyFeedbackSettings() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            // The process may not get another chance to run once it is in
            // the background, so every queued write lands now.
            SongPerformer.shared.stop()
            progress.flush()
            library.flush()
            sessions.flush()
        }
    }

    private func applyFeedbackSettings() {
        Haptics.isEnabled = settings.hapticsEnabled
        BeatPlayer.shared.isEnabled = settings.beatEnabled
        SoundField.shared.isEnabled = settings.soundEnabled
    }

    // MARK: - Launch overrides

    /// Where the app opens. Always the title page, except when a debug build
    /// is asked to open somewhere else for a screenshot.
    private static func launchStack() -> [AppRouter.Screen] {
        #if DEBUG
        let defaults = UserDefaults.standard
        let level = defaults.integer(forKey: "uiPreviewLevel")
        if level > 0 {
            return [.home, .game(min(max(level, 1), DifficultyCurve.levelCount))]
        }
        switch defaults.string(forKey: "uiPreviewScreen") {
        case "home": return [.home]
        case "chromarcs": return [.home, .chromarcs]
        case "keepsakes": return [.home, .keepsakes]
        case "levels": return [.home, .chromarcs, .levels]
        case "settings": return [.home, .settings]
        case "howToPlay": return [.home, .howToPlay]
        case "arcComplete": return [.home, .arcComplete(1)]
        default: break
        }
        #endif
        return [.title]
    }

    /// Screen overrides for screenshots and UI tests, taken from launch
    /// arguments. Debug builds only: a release build ignores all of them.
    ///
    /// iOS folds `-key value` launch arguments into the argument domain of
    /// `UserDefaults`, which is volatile, so none of this is written back and
    /// a normal launch is unaffected. CI uses it to photograph a real board on
    /// a chosen ground instead of whatever the menu happens to show:
    ///
    ///     xcrun simctl launch <device> com.mattjett.swatchword \
    ///         -uiPreviewLevel 42 -uiPreviewAppearance shadow
    ///
    /// `GameScreen` reads a few more — `-uiPreviewSolved`, `-uiPreviewPaused`
    /// and `-uiPreviewReplay` — so the victory panel, the pause menu and the
    /// song can each be photographed on the real code path.
    ///
    /// Driving the ground through the app rather than `simctl ui appearance`
    /// is deliberate: that command exits zero on the runner without changing
    /// anything, so a screenshot taken after it silently photographs the wrong
    /// mode.
    private func applyLaunchOverrides() {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "uiPreviewAppearance"),
           let requested = Appearance(stored: name) {
            settings.appearance = requested
        }
        let solved = defaults.integer(forKey: "uiPreviewProgress")
        if solved > 0 { progress.preview(solved: solved) }
        if defaults.bool(forKey: "uiPreviewKeepsakes") { library.preview() }
        #endif
    }
}
