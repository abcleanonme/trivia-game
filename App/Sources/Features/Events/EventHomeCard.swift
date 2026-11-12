import SwiftUI
import TriviaKit

/// This week's themed event: one card on Home while it runs.
struct EventHomeCard: View {
    let onPlay: (WeeklyEvent, Int) -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let event = store.currentEvent
        let progress = store.currentEventProgress
        let today = store.today
        let daysLeft = 6 - (today - today.weekStart)
        let reward = CosmeticCatalog.item(event.rewardID)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("This week")
                Spacer()
                Text(daysLeft == 0 ? "Last day" : "\(daysLeft + 1) days left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            Label(event.title, systemImage: event.systemImage)
                .font(Theme.display(.title2))
                .foregroundStyle(Theme.ink)
            Text(event.blurb)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            EventTrack(progress: progress)
            if let reward {
                Text(progress.completed
                     ? "Unlocked: \(reward.name) \(reward.slot.title.lowercased())"
                     : "Fill the track to unlock the \(reward.name) \(reward.slot.title.lowercased())")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
            Button { onPlay(event, today.weekIndex) } label: {
                Text(progress.rounds == 0 ? "Play event round" : "Play again")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(drop: 4)
    }
}

struct EventTrack: View {
    let progress: EventProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.spark)
                        .frame(width: geo.size.width * progress.fraction)
                    ForEach(WeeklyEvent.milestones, id: \.fraction) { m in
                        Circle()
                            .fill(progress.fraction >= m.fraction ? Theme.ink : Theme.card)
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                            .frame(width: 10, height: 10)
                            .offset(x: geo.size.width * m.fraction - 5)
                    }
                }
            }
            .frame(height: 14)
            Text("\(min(progress.points, WeeklyEvent.trackLength).formatted()) / \(WeeklyEvent.trackLength.formatted()) event points")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Event track \(Int(progress.fraction * 100)) percent full")
    }
}
