import SwiftUI

/// Top-level navigation.
///
/// iPhone Duo: we rely on the standard `TabView` container so the system can
/// show a bottom tab bar on the outer display and a sidebar on the inner
/// display, and lay toolbar items out vertically. Never branch on idiom,
/// orientation, or `UIScreen.main`; use size classes and local geometry.
struct RootView: View {
    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var gameCenter = gameCenter
        TabView {
            Tab("Play", systemImage: "questionmark.circle") {
                NavigationStack { HomeView() }
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                NavigationStack { ProfileView() }
            }
            Tab("Friends", systemImage: "person.2") {
                NavigationStack { FriendsView() }
            }
            .badge(gameCenter.yourTurnCount)
            Tab("Settings", systemImage: "gear") {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Turn events only arrive while the app runs, so catch up on
        // anything that happened while it was in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await gameCenter.refresh() } }
        }
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
