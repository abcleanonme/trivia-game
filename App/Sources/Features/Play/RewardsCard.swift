import SwiftUI
import TriviaKit

/// End-of-round list of level-ups, event progress, stamps and unlocks.
struct RewardsCard: View {
    let rewards: RoundRewards

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Unlocked")
            ForEach(rewards.levelUps, id: \.category) { up in
                line("chart.line.uptrend.xyaxis", "\(up.category) level \(up.level)", "+\(up.sparks) Sparks")
            }
            if rewards.eventSparks > 0 {
                line("flag.fill", "Event milestone", "+\(rewards.eventSparks) Sparks")
            }
            ForEach(rewards.newStamps) { stamp in
                line(stamp.systemImage, stamp.name, stamp.title.map { "New title: \($0)" } ?? "New stamp")
            }
            ForEach(rewards.unlocked) { item in
                line("paintpalette.fill", item.name, "New \(item.slot.title.lowercased()) for your Player Card")
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func line(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
