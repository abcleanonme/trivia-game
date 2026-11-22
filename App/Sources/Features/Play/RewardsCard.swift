import SwiftUI
import TriviaKit

/// End-of-round list of level-ups, event progress, stamps and unlocks.
struct RewardsCard: View {
    let rewards: RoundRewards

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
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
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func line(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
