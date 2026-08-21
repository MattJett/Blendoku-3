import SwiftUI

@main
@MainActor
struct Blendoku3App: App {
    @State private var router = AppRouter()
    @State private var catalog = LevelCatalog()
    @State private var progress = ProgressStore()
    @State private var settings = GameSettings()
    @State private var library = BlendLibrary()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(catalog)
                .environment(progress)
                .environment(settings)
                .environment(library)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onAppear {
                    Haptics.isEnabled = settings.hapticsEnabled
                    applyLaunchOverrides()
                }
                .onChange(of: settings.hapticsEnabled) { _, enabled in
                    Haptics.isEnabled = enabled
                }
        }
    }

    /// Screen overrides for screenshots, taken from launch arguments.
    ///
    /// iOS folds `-key value` launch arguments into the argument domain of
    /// `UserDefaults`, which is volatile, so none of this is written back and
    /// a normal launch is unaffected. CI uses it to photograph a real board on
    /// a chosen ground instead of the menu in whatever mode it happens to be:
    ///
    ///     xcrun simctl launch <device> com.mattjett.swatchword \
    ///         -uiPreviewLevel 42 -uiPreviewAppearance paper
    ///
    /// `GameScreen` reads one more of these, `-uiPreviewSolved`, which finishes
    /// the board so the victory panel can be photographed.
    ///
    /// Driving the ground through the app rather than `simctl ui appearance`
    /// is deliberate: that command exits zero on the runner without changing
    /// anything, so a screenshot taken after it silently photographs the wrong
    /// mode. This also puts the real Settings code path under the camera.
    private func applyLaunchOverrides() {
        let defaults = UserDefaults.standard

        if let name = defaults.string(forKey: "uiPreviewAppearance"),
           let requested = Appearance(rawValue: name.lowercased()) {
            settings.appearance = requested
        }

        let level = defaults.integer(forKey: "uiPreviewLevel")
        guard level > 0 else { return }
        router.push(.game(min(max(level, 1), DifficultyCurve.levelCount)))
    }
}
