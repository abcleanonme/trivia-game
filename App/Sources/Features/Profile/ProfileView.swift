import SwiftUI
import TriviaKit

/// You: Player Card, Daily streak, category mastery, stamps, friends, and
/// the questions you've written.
struct ProfileView: View {
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let p = store.progress
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    PlayerCardView(look: CardLook(store: store))
                    FlowLayout(spacing: 10) {
                        NavigationLink { CardEditorView() } label: {
                            Label("Edit card", systemImage: "pencil")
                                .font(.headline).padding(.horizontal, 18).frame(minHeight: 44)
                        }
                        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                        NavigationLink { ShopView() } label: {
                            Label("Style shop", systemImage: "paintpalette.fill")
                                .font(.headline).padding(.horizontal, 18).frame(minHeight: 44)
                        }
                        .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
                    }
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
                        ("Best streak", "\(p.stats.bestStreak)", "flame"),
                        ("Survival", "\(p.stats.bestSurvival)", GameMode.survival.systemImage),
                        ("Speed", "\(p.stats.bestSpeedRound)", GameMode.speed.systemImage),
                    ])
                }

                section("Category mastery") {
                    VStack(spacing: 14) {
                        ForEach(store.bank.categories, id: \.self) { MasteryRow(category: $0) }
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
                    if p.rivals.sorted.isEmpty {
                        Text("Play a friend and your head-to-head record shows up here.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(p.rivals.sorted) { r in
                            HStack {
                                Text(r.name).font(.headline)
                                Spacer()
                                RivalryBadge(record: r)
                            }
                        }
                    }
                }

                section("Your questions") {
                    NavigationLink { SubmitQuestionView() } label: {
                        Label("Write a question", systemImage: "square.and.pencil")
                            .font(.headline).padding(.horizontal, 18).frame(minHeight: 44)
                    }
                    .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                    ForEach(p.submissions) { s in
                        HStack(alignment: .top) {
                            Text(s.prompt).font(.subheadline).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(s.status.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(s.status == .accepted ? Theme.correct : Theme.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .themeBackground()
        .navigationTitle("Profile")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func statGrid(_ items: [(String, String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.0, systemImage: item.2)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(item.1).font(Theme.display(.title2)).foregroundStyle(Theme.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 18)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct MasteryRow: View {
    let category: String
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let correct = store.progress.masteryCorrect[category, default: 0]
        let level = Mastery.level(forCorrect: correct)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category).font(.headline).foregroundStyle(Theme.ink)
                ForEach(Mastery.badgeLevels.sorted(), id: \.self) { badge in
                    if level >= badge {
                        Image(systemName: badge >= 10 ? "rosette" : "medal.fill")
                            .foregroundStyle(Theme.spark)
                            .shadow(color: Theme.shadow, radius: 0, x: 0.6, y: 0.6)
                    }
                }
                Spacer()
                Text(level == 0 ? "Not ranked" : "Level \(level)")
                    .font(.subheadline.bold())
                    .foregroundStyle(level == 0 ? Theme.muted : Theme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * Mastery.progress(forCorrect: correct))
                }
            }
            .frame(height: 8)
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
