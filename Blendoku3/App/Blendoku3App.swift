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
                .preferredColorScheme(.dark)
                .onAppear { Haptics.isEnabled = settings.hapticsEnabled }
                .onChange(of: settings.hapticsEnabled) { _, enabled in
                    Haptics.isEnabled = enabled
                }
        }
    }
}
