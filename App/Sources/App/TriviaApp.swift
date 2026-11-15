import SwiftUI

@main
struct TriviaApp: App {
    @State private var store: PlayerStore
    @State private var gameCenter: GameCenter

    init() {
        let store = PlayerStore()
        _store = State(initialValue: store)
        _gameCenter = State(initialValue: GameCenter(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(gameCenter)
                .tint(Theme.accent)
                .onAppear { gameCenter.authenticate() }
        }
    }
}
