import SwiftUI

@main
struct TriviaApp: App {
    @State private var store = PlayerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
                // Dark themes (Midnight, Neon Arcade) force dark mode.
                .preferredColorScheme(ThemeManager.shared.palette.scheme)
        }
    }
}
