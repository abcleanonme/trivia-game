import SwiftUI
import TriviaKit

/// You: Player Card, Daily streak, records, category mastery, stamps and
/// head-to-head records with friends.
struct ProfileView: View {
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let p = store.progress
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                // Same compact header as Home and Friends.
                Text("Profile")
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, -Space.s)
                VStack(spacing: Space.m) {
                    // The card itself opens the Studio, so there's one obvious way in.
                    NavigationLink { CardStudioView() } label: {
                        PlayerCardView(look: CardLook(store: store))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Customize card")
                    HStack(spacing: Space.s) {
                        NavigationLink { CardStudioView() } label: {
                            Label("Customize", systemImage: "paintbrush.pointed.fill")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                        NavigationLink { ShopView() } label: {
                            Label("Style shop", systemImage: "paintpalette.fill")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
                    }
                    NavigationLink { PowerUpShopView() } label: {
                        Label("Power-up shop", systemImage: "bolt.fill")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                }

                section("Daily") {
                    statGrid([
                        ("Streak", "\(store.dailyStreak)", "flame.fill"),
                        ("Best", "\(p.streak.best)", "trophy.fill"),
                        ("Played", "\(p.stats.dailiesPlayed)", "calendar"),
                        ("Freeze", p.streak.freezes > 0 ? "Ready" : "None", "snowflake"),
                    ])
                    Text("Play \(DailyStreak.daysPerFreeze) days in a row to earn a streak freeze. It covers one missed day.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }

                section("Records") {
                    statGrid([
                        ("Rounds", "\(p.stats.roundsPlayed)", "list.number"),
                        ("Top run", "\(p.stats.bestStreak)", "flame"),
                        ("Survival", "\(p.stats.bestSurvival)", GameMode.survival.systemImage),
                        ("Speed", "\(p.stats.bestSpeedRound)", GameMode.speed.systemImage),
                    ])
                }

                section("Category mastery") {
                    // One card with hairlines between rows reads as a list
                    // instead of fourteen loose blocks.
                    DividedCard(store.bank.categories, id: \.self, verticalPadding: 0) { category in
                        MasteryRow(category: category)
                            .padding(.top, Space.s)
                            .padding(.bottom, Space.m)
                    }
                }

                section("Stamps") {
                    if p.stamps.isEmpty {
                        Text("Stamps come from big moments: a perfect round, a 7-day Daily streak, level 5 in a category.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(p.stamps.sorted { $0.name < $1.name }) { stamp in
                                Label(stamp.name, systemImage: stamp.systemImage)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.pill.fill(Theme.card))
                                    .overlay(Theme.pill.stroke(Theme.ink, lineWidth: 1.5))
                            }
                        }
                    }
                }

                section("Friends") {
                    if p.rivals.records.isEmpty {
                        Text("Play a friend and your head-to-head record shows up here.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        DividedCard(p.rivals.sorted, verticalPadding: 0) { r in
                            HStack {
                                Text(r.name).font(.headline).foregroundStyle(Theme.ink)
                                Spacer()
                                RecordChip(record: r)
                            }
                            .frame(minHeight: 44)
                            .padding(.vertical, Space.xs)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.m)
            .readableWidth()
        }
        .themeBackground()
        .navigationTitle("Profile")
        .toolbar(.hidden, for: .navigationBar)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(title)
            content()
        }
    }

    private func statGrid(_ items: [(String, String, String)]) -> some View {
        StatStrip(items: items.map { StatStrip.Item(label: $0.0, value: $0.1, systemImage: $0.2) })
    }
}

struct MasteryRow: View {
    let category: String
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let correct = store.progress.masteryCorrect[category, default: 0]
        let level = Mastery.level(forCorrect: correct)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Space.xs) {
                Text(category).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                ForEach(Mastery.badgeLevels.sorted(), id: \.self) { badge in
                    if level >= badge {
                        Image(systemName: badge >= 10 ? "rosette" : "medal.fill")
                            .foregroundStyle(Theme.spark)
                            .shadow(color: Theme.shadow, radius: 0, x: 0.6, y: 0.6)
                    }
                }
                Spacer()
                Text(level == 0 ? "Not ranked" : "Level \(level)")
                    .font(.footnote.bold())
                    .foregroundStyle(level == 0 ? Theme.muted : Theme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * Mastery.progress(forCorrect: correct))
                }
            }
            .frame(height: 6)
            Text(level >= Mastery.maxLevel
                 ? "\(correct.formatted()) correct · mastered"
                 : "\(correct.formatted()) correct · \(Mastery.remaining(forCorrect: correct)) to level \(level + 1)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category), \(level == 0 ? "not ranked" : "level \(level)"), \(correct) correct, \(Mastery.remaining(forCorrect: correct)) to next level")
    }
}

#Preview {
    NavigationStack { ProfileView() }.environment(PlayerStore.preview)
}
