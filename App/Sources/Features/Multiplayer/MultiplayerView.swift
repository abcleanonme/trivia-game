import SwiftUI

/// Placeholder. Planned: Game Center (GameKit) for real-time matches,
/// turn-based play, and leaderboards. No ad SDKs.
struct MultiplayerView: View {
    var body: some View {
        ContentUnavailableView("Multiplayer coming soon",
                               systemImage: "person.2",
                               description: Text("Play live or turn-based against friends."))
            .navigationTitle("Multiplayer")
    }
}
