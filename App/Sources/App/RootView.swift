import SwiftUI

/// Top-level navigation.
///
/// iPhone Duo: we rely on the standard `TabView` container so the system can
/// show a bottom tab bar on the outer display and a sidebar on the inner
/// display, and lay toolbar items out vertically. Never branch on idiom,
/// orientation, or `UIScreen.main`; use size classes and local geometry.
struct RootView: View {
    @Environment(GameCenter.self) private var gameCenter

    var body: some View {
        @Bindable var gameCenter = gameCenter
        TabView {
            Tab("Play", systemImage: "questionmark.circle") {
                NavigationStack { HomeView() }
            }
            Tab("Friends", systemImage: "person.2") {
                NavigationStack { FriendsView() }
            }
            Tab("Settings", systemImage: "gear") {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // On the root, not the Friends tab, so a challenge opened from a
        // Game Center notification shows whichever tab is up.
        .fullScreenCover(item: $gameCenter.activeRound) { round in
            ChallengeGameView(round: round)
        }
    }
}

#Preview {
    let store = PlayerStore.preview
    RootView()
        .environment(store)
        .environment(GameCenter(store: store, demo: true))
}
