import SwiftUI
import TriviaKit

/// The Daily tab: today's Daily, a teaser for tomorrow's, friends' scores,
/// a streak calendar and every past Daily.
struct DailyTabView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage(SettingKey.relaxedMode) private var relaxedMode = false
    @State private var round: RoundRequest?
    @State private var tomorrow: DailyPreview?
    @State private var showAll = false

    /// Past Dailies shown before "Show all".
    private static let recentCount = 7

    var body: some View {
        let today = store.today
        let history = store.progress.dailyHistory(before: today)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ChallengeTabHeader(title: "Daily", subtitle: "Same 10 for everyone. One try a day.") {
                    StreakBadge(days: store.dailyStreak, freezes: store.progress.streak.freezes)
                }
                DailyTodayCard(record: store.todaysDaily, day: today) {
                    round = RoundRequest(kind: .daily(store.today))
                }
                upNext(today)
                ChallengeBoardPanel(choices: [
                    BoardChoice(label: "Today", systemImage: "calendar", board: .daily),
                    BoardChoice(label: "Yesterday", systemImage: "clock.arrow.circlepath", board: .daily, previous: true),
                    BoardChoice(label: "Streak", systemImage: "flame.fill", board: .streak),
                ]) { choice in
                    switch (choice.board, choice.previous) {
                    case (.daily, false): "None of your friends have posted today's Daily yet. Play it and share your card to get them going."
                    case (.daily, true): "None of your friends played yesterday's Daily."
                    default: "No friends on this board yet."
                    }
                }
                DailyCalendar(today: today)
                stats
                past(history)
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
        .task(id: today) {
            let bank = store.bank
            tomorrow = await Task.detached(priority: .utility) {
                DailyChallenge.preview(for: today + 1, from: bank)
            }.value
        }
    }

    // MARK: Up next

    private func upNext(_ today: Day) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Up next · Daily #\((today + 1).dailyNumber)")
                Spacer()
                MidnightCountdown(prefix: "in ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Tomorrow's mix")
                    .font(Theme.display(.title3))
                    .foregroundStyle(Theme.ink)
                if let tomorrow {
                    FlowLayout(spacing: 6) {
                        ForEach(tomorrow.categories) { c in
                            HStack(spacing: 4) {
                                Image(systemName: CategoryStyle.symbol(for: c.category))
                                    .foregroundStyle(Theme.accent)
                                Text(c.category)
                                Text("×\(c.count)").foregroundStyle(Theme.muted)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 28)
                            .background(Theme.pill.fill(Theme.paper))
                            .overlay(Theme.pill.stroke(Theme.line, lineWidth: 1))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(c.count) \(c.category)")
                        }
                    }
                    Text(tomorrow.hardCount == 0 ? "No hard ones. Keep that streak going."
                         : tomorrow.hardCount == 1 ? "1 hard one in there. Questions stay hidden until midnight."
                         : "\(tomorrow.hardCount) hard ones in there. Questions stay hidden until midnight.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: Stats

    private var stats: some View {
        let s = store.progress.dailySummary
        return StatStrip(items: [
            .init(label: "Played", value: "\(s.played)", systemImage: "calendar"),
            .init(label: "Perfect", value: "\(s.perfect)", systemImage: "star.fill"),
            .init(label: "Average", value: s.averageCorrect.map { String(format: "%.1f", $0) } ?? "–",
                  systemImage: "checkmark.circle"),
            .init(label: "Best streak", value: "\(store.progress.streak.best)", systemImage: "trophy.fill"),
        ])
    }

    // MARK: Past Dailies

    @ViewBuilder private func past(_ history: [DailyRecord]) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Past Dailies")
            if history.isEmpty {
                Text("Your past Dailies land here, so you can look back at how each one went.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.cardPadding)
                    .card()
            } else {
                let shown = showAll ? history : Array(history.prefix(Self.recentCount))
                DividedCard(shown, id: \.day) { record in
                    NavigationLink { DailyRecordDetail(record: record) } label: {
                        PastDailyRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
                if history.count > Self.recentCount {
                    Button(showAll ? "Show fewer" : "Show all \(history.count)") {
                        withAnimation { showAll.toggle() }
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
            }
        }
    }
}

/// Today's Daily, big: play it, or see your grid and share it.
private struct DailyTodayCard: View {
    let record: DailyRecord?
    let day: Day
    let onPlay: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily #\(day.dailyNumber) · \(day.shortDate(weekday: true))")
                    .eyebrow()
                    .opacity(0.9)
                Spacer()
                if record != nil {
                    MidnightCountdown(prefix: "New in ")
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
            }
            if let record {
                Text(record.finished ? "\(record.correct) of \(record.marks.count) right" : "Left early today")
                    .font(Theme.display(.title2))
                Text("\(record.points.formatted()) pts" + (record.relaxed ? " · relaxed" : ""))
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.92)
                if !record.marks.isEmpty {
                    DailyGrid(marks: record.marks, size: typeSize.isAccessibilitySize ? 20 : 24)
                        .padding(.leading, -3)
                    DailyShareButton(record: record)
                }
            } else {
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
                layout {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Today's ten\nare ready.")
                            .font(Theme.display(.title2))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("+\(DailyChallenge.finishBonus) Sparks, or +\(DailyChallenge.perfectBonus) for a perfect 10.")
                            .font(.footnote)
                            .opacity(0.92)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onPlay) {
                        Label("Play", systemImage: "play.fill")
                            .font(.title3.bold())
                            .padding(.horizontal, Space.l)
                            .frame(minHeight: 52)
                    }
                    .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
                    .accessibilityLabel("Play the Daily")
                }
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.accent, radius: Theme.cardRadius, drop: 5)
    }
}

/// The last five weeks, Monday to Sunday: a star for a perfect Daily, a
/// filled square for played, a dashed one for left early, an empty one for
/// missed. Shape carries the meaning as well as color.
private struct DailyCalendar: View {
    let today: Day

    @Environment(PlayerStore.self) private var store
    private static let weeks = 5
    private static let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let first = Day.firstDay(ofWeek: today.weekIndex - Self.weeks + 1)
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Your calendar")
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { _, d in
                        Text(d)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
                ForEach(0..<Self.weeks, id: \.self) { w in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { d in
                            let day = first + (w * 7 + d)
                            DayCell(day: day, status: store.progress.dailyStatus(on: day, today: today),
                                    isToday: day == today)
                        }
                    }
                }
                legend.padding(.top, Space.xs)
            }
            .padding(Theme.cardPadding)
            .card()
        }
    }

    private var legend: some View {
        FlowLayout(spacing: Space.m) {
            legendItem("Perfect", .perfect)
            legendItem("Played", .played)
            legendItem("Left early", .leftEarly)
            legendItem("Missed", .missed)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.muted)
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: String, _ status: DailyDayStatus) -> some View {
        HStack(spacing: 4) {
            DayMark(status: status).frame(width: 12, height: 12)
            Text(title)
        }
    }
}

private struct DayCell: View {
    let day: Day
    let status: DailyDayStatus
    let isToday: Bool

    var body: some View {
        DayMark(status: status)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 40)
            .frame(maxWidth: .infinity)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Theme.ink, lineWidth: 2)
                        .padding(-3)
                        .frame(maxWidth: 40)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.shortDate(weekday: true)), \(label)")
    }

    private var label: String {
        switch status {
        case .perfect: "perfect"
        case .played: "played"
        case .leftEarly: "left early"
        case .missed: "missed"
        case .open: "not played yet"
        case .upcoming: "coming up"
        case .beforeLaunch: "before the Daily began"
        }
    }
}

private struct DayMark: View {
    let status: DailyDayStatus

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack {
            switch status {
            case .perfect:
                shape.fill(Theme.spark)
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.onSpark)
            case .played:
                shape.fill(Theme.accent)
            case .leftEarly:
                shape.strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
            case .missed, .open:
                shape.strokeBorder(Theme.line, lineWidth: 1.5)
            case .upcoming, .beforeLaunch:
                shape.fill(Theme.line.opacity(0.35))
            }
        }
    }
}

private struct PastDailyRow: View {
    let record: DailyRecord

    var body: some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(record.day.dailyNumber)")
                        .font(.headline.monospacedDigit())
                    Text(record.day.shortDate(weekday: true))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                if record.marks.isEmpty {
                    Text("Left before the first answer").font(.caption).foregroundStyle(Theme.muted)
                } else {
                    DailyGrid(marks: record.marks, size: 11).padding(.leading, -1.5)
                }
            }
            Spacer(minLength: Space.s)
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.marks.isEmpty ? "–" : "\(record.correct)/\(record.marks.count)")
                    .font(.headline.monospacedDigit())
                HStack(spacing: 4) {
                    if record.relaxed { TagPill(text: "Relaxed") }
                    if !record.finished { TagPill(text: "Left early") }
                    Text("\(record.points.formatted()) pts")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One past Daily: the share card, the numbers, and sharing it again.
struct DailyRecordDetail: View {
    let record: DailyRecord

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                VStack(spacing: Space.s) {
                    Text(record.day.shortDate(weekday: true))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    if record.marks.isEmpty {
                        Text("Left before the first answer")
                            .font(Theme.display(.title3))
                    } else {
                        DailyGrid(marks: record.marks, size: 24)
                    }
                    if record.relaxed { TagPill(text: "Relaxed · no clock") }
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(Theme.cardPadding)
                .card(drop: 4)
                StatStrip(items: [
                    .init(label: "Right", value: "\(record.correct)/\(record.marks.count)", systemImage: "checkmark.circle"),
                    .init(label: "Points", value: record.points.formatted(), systemImage: "sum"),
                    .init(label: "Fast", value: "\(record.marks.filter(\.fast).count)", systemImage: "bolt.fill"),
                    .init(label: "Streak", value: "\(record.streak)", systemImage: "flame.fill"),
                ])
                if !record.finished {
                    Text("You left this one early, so it didn't count toward your streak.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                if !record.marks.isEmpty { DailyShareButton(record: record) }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, Space.l)
            .readableWidth()
        }
        .themeBackground()
        .navigationTitle("Daily #\(record.day.dailyNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let store = PlayerStore.preview
    NavigationStack { DailyTabView() }
        .environment(store)
        .environment(GameCenter(store: store, demo: true))
}
