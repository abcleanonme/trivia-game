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
            Tab("Daily", systemImage: "calendar") {
                NavigationStack { DailyTabView() }
            }
            Tab("Weekly", systemImage: "star.circle") {
                NavigationStack { WeeklyTabView() }
            }
            Tab("Friends", systemImage: "person.2") {
                NavigationStack { FriendsView() }
            }
            .badge(gameCenter.yourTurnCount)
            // Five tabs fit the iPhone tab bar without a "More" tab, so
            // Settings opens from the gear on Profile.
            Tab("Profile", systemImage: "person.crop.circle") {
                NavigationStack { ProfileView() }
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
        .sheet(item: $gameCenter.reviewing) { match in
            NavigationStack { MatchBreakdownView(match: match, me: gameCenter.localPlayerID) }
        }
    }
}

#Preview {
    let store = PlayerStore.preview
    RootView()
        .environment(store)
        .environment(GameCenter(store: store, demo: true))
}
