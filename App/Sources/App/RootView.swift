import SwiftUI

/// Top-level navigation.
///
/// iPhone Duo: we rely on the standard `TabView` container so the system can
/// show a bottom tab bar on the outer display and a sidebar on the inner
/// display, and lay toolbar items out vertically. Never branch on idiom,
/// orientation, or `UIScreen.main`; use size classes and local geometry.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Play", systemImage: "questionmark.circle") {
                NavigationStack { HomeView() }
            }
            Tab("Multiplayer", systemImage: "person.2") {
                NavigationStack { MultiplayerView() }
            }
            Tab("Settings", systemImage: "gear") {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview { RootView().environment(PlayerStore.preview) }
