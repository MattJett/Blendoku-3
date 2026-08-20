import SwiftUI

@main
@MainActor
struct Blendoku3App: App {
    @State private var router = AppRouter()
    @State private var catalog = LevelCatalog()
    @State private var progress = ProgressStore()
    @State private var settings = GameSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(catalog)
                .environment(progress)
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .onAppear {
                    Haptics.isEnabled = settings.hapticsEnabled
                    openPreviewLevelIfAsked()
                }
                .onChange(of: settings.hapticsEnabled) { _, enabled in
                    Haptics.isEnabled = enabled
                }
        }
    }

    /// Opens straight into a level when launched with `-uiPreviewLevel <n>`.
    /// iOS folds `-key value` launch arguments into the argument domain of
    /// `UserDefaults`, which is volatile, so this leaves nothing behind. CI
    /// uses it to photograph a real board instead of the menu:
    ///
    ///     xcrun simctl launch <device> com.mattjett.blendoku3 -uiPreviewLevel 42
    private func openPreviewLevelIfAsked() {
        let requested = UserDefaults.standard.integer(forKey: "uiPreviewLevel")
        guard requested > 0 else { return }
        router.push(.game(min(max(requested, 1), DifficultyCurve.levelCount)))
    }
}
