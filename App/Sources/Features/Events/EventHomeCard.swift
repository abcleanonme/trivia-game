import SwiftUI
import TriviaKit

/// This week's themed event: one card on Home while it runs.
struct EventHomeCard: View {
    let onPlay: (WeeklyEvent, Int) -> Void

    @Environment(PlayerStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let event = store.currentEvent
        let progress = store.currentEventProgress
        let today = store.today
        let daysLeft = 6 - (today - today.weekStart)
        let reward = CosmeticCatalog.item(event.rewardID)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                SectionLabel("This week")
                Spacer()
                Text(daysLeft == 0 ? "Last day" : "\(daysLeft + 1) days left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            layout {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Label(event.title, systemImage: event.systemImage)
                        .font(Theme.display(.title3))
                        .foregroundStyle(Theme.ink)
                    Text(event.blurb)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { onPlay(event, today.weekIndex) } label: {
                    Label(progress.rounds == 0 ? "Play" : "Again",
                          systemImage: progress.rounds == 0 ? "play.fill" : "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, Space.l)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
                .accessibilityLabel(progress.rounds == 0 ? "Play event round" : "Play the event again")
            }
            EventTrack(progress: progress, reward: reward)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(drop: 4)
    }
}

struct EventTrack: View {
    let progress: EventProgress
    var reward: Cosmetic? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
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
            .frame(height: 12)
            // Points and the reward share one caption line.
            HStack(alignment: .firstTextBaseline) {
                Text("\(min(progress.points, WeeklyEvent.trackLength).formatted()) / \(WeeklyEvent.trackLength.formatted()) pts")
                Spacer(minLength: Space.s)
                if let reward {
                    Text(progress.completed ? "Unlocked: \(reward.name)" : "Reward: \(reward.name) \(reward.slot.title.lowercased())")
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "Event track \(Int(progress.fraction * 100)) percent full"
        if let reward { text += progress.completed ? ", unlocked \(reward.name)" : ", fill it to unlock \(reward.name)" }
        return text
    }
}
