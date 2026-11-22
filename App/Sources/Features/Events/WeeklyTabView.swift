import SwiftUI
import TriviaKit

/// The Weekly tab: this week's event, friends' best rounds, what's coming
/// next, and every past event you played.
struct WeeklyTabView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage(SettingKey.relaxedMode) private var relaxedMode = false
    @State private var round: RoundRequest?

    var body: some View {
        let today = store.today
        let upcoming = WeeklyEvent.upcoming(after: today, count: 3)
        let history = store.progress.eventHistory(before: today.weekIndex)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ChallengeTabHeader(title: "Weekly", subtitle: "A new themed event every Monday.") {
                    SparksPill(amount: store.wallet.sparks)
                }
                ThisWeekCard(today: today) { event, week in
                    round = RoundRequest(kind: .event(event, week: week))
                }
                ChallengeBoardPanel(choices: [
                    BoardChoice(label: "This week", systemImage: "star.circle.fill", board: .weekly),
                    BoardChoice(label: "Last week", systemImage: "clock.arrow.circlepath", board: .weekly, previous: true),
                ]) { choice in
                    choice.previous
                        ? "None of your friends played last week's event."
                        : "None of your friends have played this week's event yet. Your best timed round is your score."
                }
                if let next = upcoming.first {
                    NextWeekCard(week: next, today: today)
                }
                if upcoming.count > 1 {
                    VStack(alignment: .leading, spacing: Space.s) {
                        SectionLabel("Later")
                        DividedCard(Array(upcoming.dropFirst())) { UpcomingRow(week: $0) }
                    }
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("Past weeks")
                    if history.isEmpty {
                        Text("Events you play show up here with your points, best round and any reward you earned.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.cardPadding)
                            .card()
                    } else {
                        DividedCard(history) { PastWeekRow(week: $0) }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.xl)
            .readableWidth()
        }
        .themeBackground()
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $round) { request in
            GameView(request: request, relaxed: relaxedMode)
        }
    }
}

/// Round icon badge for an event.
private struct EventBadge: View {
    let event: WeeklyEvent
    var size: CGFloat = 52
    var fill: Color = Theme.accent

    var body: some View {
        Image(systemName: event.systemImage)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

private struct ThisWeekCard: View {
    let today: Day
    let onPlay: (WeeklyEvent, Int) -> Void

    @Environment(PlayerStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let event = store.currentEvent
        let progress = store.currentEventProgress
        let daysLeft = 7 - (today - today.weekStart)
        let reward = CosmeticCatalog.item(event.rewardID)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("This week · \(today.weekStart.weekRange())")
                Spacer()
                Text(daysLeft == 1 ? "Last day" : "\(daysLeft) days left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(daysLeft == 1 ? Theme.wrong : Theme.muted)
            }
            layout {
                EventBadge(event: event, size: 60)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(event.title)
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.ink)
                    Text(event.blurb)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { onPlay(event, today.weekIndex) } label: {
                Label(progress.rounds == 0 ? "Play this week's round" : "Play again",
                      systemImage: progress.rounds == 0 ? "play.fill" : "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            EventTrack(progress: progress, reward: reward)
            StatStrip(items: [
                .init(label: "Rounds", value: "\(progress.rounds)", systemImage: "arrow.clockwise"),
                .init(label: "Best round", value: progress.bestRound > 0 ? progress.bestRound.formatted() : "–",
                      systemImage: "trophy.fill"),
                .init(label: "Total", value: progress.points.formatted(), systemImage: "sum"),
            ])
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(drop: 5)
    }
}

private struct NextWeekCard: View {
    let week: EventWeek
    let today: Day

    var body: some View {
        let reward = CosmeticCatalog.item(week.event.rewardID)
        let daysToMonday = 7 - (today - today.weekStart)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Next week · \(week.start.weekRange())")
                Spacer()
                MidnightCountdown(days: daysToMonday, prefix: "Starts in ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            HStack(alignment: .center, spacing: Space.m) {
                EventBadge(event: week.event, size: 46, fill: Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(week.event.title)
                        .font(Theme.display(.title3))
                        .foregroundStyle(Theme.ink)
                    Text(week.event.blurb)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let reward {
                        TagPill(text: "Reward: \(reward.name) \(reward.slot.title.lowercased())",
                                systemImage: "gift.fill", fill: Theme.spark, foreground: Theme.onSpark)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.cardPadding)
            .card()
        }
    }
}

private struct UpcomingRow: View {
    let week: EventWeek

    var body: some View {
        HStack(spacing: Space.m) {
            EventBadge(event: week.event, size: 32, fill: Theme.muted)
            Text(week.event.title).font(.headline)
            Spacer(minLength: Space.s)
            Text(week.start.weekRange())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct PastWeekRow: View {
    let week: EventWeek

    var body: some View {
        let p = week.progress
        let reward = CosmeticCatalog.item(week.event.rewardID)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.m) {
                EventBadge(event: week.event, size: 36, fill: p.completed ? Theme.accent : Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(week.event.title).font(.headline)
                    Text(week.start.weekRange())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: Space.s)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(p.points.formatted()) pts")
                        .font(.headline.monospacedDigit())
                    Text(p.rounds == 1 ? "1 round" : "\(p.rounds) rounds")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 6) {
                if p.bestRound > 0 {
                    TagPill(text: "Best \(p.bestRound.formatted())", systemImage: "trophy.fill")
                }
                if p.completed, let reward {
                    TagPill(text: "Unlocked \(reward.name)", systemImage: "gift.fill",
                            fill: Theme.spark, foreground: Theme.onSpark)
                } else {
                    TagPill(text: "Track \(Int(p.fraction * 100))%", systemImage: "flag.fill")
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let store = PlayerStore.preview
    NavigationStack { WeeklyTabView() }
        .environment(store)
        .environment(GameCenter(store: store, demo: true))
}
