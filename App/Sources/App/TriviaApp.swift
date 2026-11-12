import SwiftUI

@main
struct TriviaApp: App {
    @State private var store = PlayerStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
        }
    }
}
