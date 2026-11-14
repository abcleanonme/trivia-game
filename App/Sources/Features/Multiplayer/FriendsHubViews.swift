import SwiftUI
import TriviaKit

// MARK: Leaderboards

/// Friends-only rankings: today's Daily first, then lifetime stats.
struct FriendBoardsView: View {
    @Environment(GameCenter.self) private var gameCenter
    @SceneStorage("friends.board") private var board: FriendBoard = .daily

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            FlowLayout(spacing: 6) {
                ForEach(FriendBoard.allCases) { b in
                    let on = b == board
                    Button { board = b } label: {
                        Label(b.shortTitle, systemImage: b.systemImage)
                            .labelStyle(CompactLabelStyle())
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.accent : Theme.card,
                                                   foreground: on ? .white : Theme.ink,
                                                   shape: AnyShape(Theme.pill),
                                                   depth: on ? 2 : 3))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(board.title).font(Theme.display(.title3))
                Text(caption).font(.footnote).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink)

            content
        }
        .task(id: board) { await gameCenter.loadBoard(board) }
    }

    private var caption: String {
        switch board {
        case .daily: "Same ten questions for everyone today. Timed Dailies only."
        case .streak: "Days in a row with a Daily played."
        case .challengeWins: "Friend challenges won, all time."
        case .correct: "Every right answer, all time."
        case .survival: "Longest Survival run."
        case .speed: "Most right in one Speed round."
        }
    }

    @ViewBuilder private var content: some View {
        switch gameCenter.boards[board] {
        case nil, .loading?:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, Space.xl)
        case .failed(let message)?:
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.cardPadding)
                .card()
        case .loaded(let entries)?:
            if entries.filter({ !$0.isMe }).isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    if let me = entries.first(where: \.isMe) {
                        Text("You: \(board.format(me.value))").font(.headline)
                    }
                    Text(board.isDaily
                         ? "None of your friends have posted today's Daily yet. Play it and share your card to get them going."
                         : "No friends on this board yet. Challenge someone, and they'll show up once they play.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.cardPadding)
                .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                        if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                        BoardRow(entry: entry, board: board)
                    }
                }
                .padding(.horizontal, Theme.cardPadding)
                .padding(.vertical, Space.xs)
                .card()
            }
        }
    }
}

private struct BoardRow: View {
    let entry: BoardEntry
    let board: FriendBoard

    var body: some View {
        HStack(spacing: Space.m) {
            rank
            PlayerBadge(name: entry.name, size: 34)
            Text(entry.isMe ? "You" : entry.name)
                .font(entry.isMe ? .headline.weight(.heavy) : .headline)
                .lineLimit(1)
            Spacer(minLength: Space.s)
            Text(board.format(entry.value))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        // Highlight bleeds outward so your row's content lines up with the others.
        .background {
            if entry.isMe {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.spark.opacity(0.25))
                    .padding(.horizontal, -Space.s)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(entry.rank), \(entry.isMe ? "you" : entry.name), \(board.format(entry.value))")
    }

    @ViewBuilder private var rank: some View {
        let medal: Color? = switch entry.rank {
        case 1: Theme.spark
        case 2: Color(light: 0xC9CCD6, dark: 0x9EA3B5)
        case 3: Color(light: 0xE0A36B, dark: 0xB97F4C)
        default: nil
        }
        Text("\(entry.rank)")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(medal == nil ? Theme.muted : Theme.onSpark)
            .frame(width: 28, height: 28)
            .background(Circle().fill(medal ?? .clear))
            .overlay(Circle().stroke(medal == nil ? .clear : Theme.ink, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

// MARK: Friends list

/// Everyone you play with: your overall record, each friend's
/// head-to-head, and the latest finished games.
struct FriendsListView: View {
    @Environment(GameCenter.self) private var gameCenter

    var body: some View {
        let overall = gameCenter.history.overall
        let rows = gameCenter.friendRows
        VStack(alignment: .leading, spacing: Space.l) {
            if overall.played > 0 {
                StatStrip(items: [
                    .init(label: "Played", value: overall.played.formatted(), systemImage: "gamecontroller.fill"),
                    .init(label: "Won", value: overall.wins.formatted(), systemImage: "trophy.fill"),
                    .init(label: "Win rate", value: winRate(overall), systemImage: "percent"),
                    .init(label: "Best", value: overall.bestScore.formatted(), systemImage: "star.fill"),
                ])
            }

            if gameCenter.friendsAccess == .notDetermined {
                findFriendsCard
            }

            if rows.isEmpty {
                Text(gameCenter.friendsAccess == .denied
                     ? "Turn on friends access for Quizio in Settings › Game Center › Friends List, or start a challenge to add someone."
                     : "No friends here yet. Start a challenge and they'll show up after you play.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("Your friends")
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, friend in
                            if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                            NavigationLink {
                                FriendDetailView(friend: friend)
                            } label: {
                                FriendRow(friend: friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.cardPadding)
                    .padding(.vertical, Space.xs)
                    .card()
                }
            }

            let recent = Array(gameCenter.history.games.prefix(8))
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("Recent games")
                    VStack(spacing: 0) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { i, game in
                            if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                            GameRow(game: game, showsOpponent: true)
                        }
                    }
                    .padding(.horizontal, Theme.cardPadding)
                    .padding(.vertical, Space.xs)
                    .card()
                }
            }
        }
    }

    private var findFriendsCard: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: "person.2.badge.plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Find your Game Center friends").font(.headline)
                Text("See who plays Quizio and challenge them in a tap.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button { Task { await gameCenter.loadFriends(ask: true) } } label: {
                    Text("Show friends").font(.subheadline.bold()).padding(.horizontal, Space.l).frame(minHeight: 40)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                .padding(.top, Space.xs)
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .card()
    }
}

private func winRate(_ s: HeadToHeadStats) -> String {
    guard s.played > 0 else { return "–" }
    return (Double(s.wins) / Double(s.played)).formatted(.percent.precision(.fractionLength(0)))
}

private struct FriendRow: View {
    let friend: Friend

    @Environment(GameCenter.self) private var gameCenter

    var body: some View {
        let stats = gameCenter.history.stats(against: friend.id)
        let record = gameCenter.rivalries.record(against: friend.id)
        let open = gameCenter.openChallenges(with: friend.id)
        HStack(spacing: Space.m) {
            PlayerBadge(name: friend.name, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name).font(.headline).lineLimit(1)
                Text(detail(stats: stats, open: open.count))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: Space.s)
            if let record, record.played > 0 { RecordChip(record: record) }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func detail(stats: HeadToHeadStats, open: Int) -> String {
        var parts: [String] = []
        if stats.played > 0 {
            parts.append(stats.played == 1 ? "1 game" : "\(stats.played) games")
            if let run = stats.runLabel { parts.append(run) }
        } else {
            parts.append("Not played yet")
        }
        if open > 0 { parts.append("\(open) in progress") }
        return joinedKeepingPhrases(parts)
    }
}

/// Joins short facts with " · " so a line can only wrap between facts,
/// never inside one ("1 in progress") or before a dot.
func joinedKeepingPhrases(_ parts: [String]) -> String {
    parts
        .flatMap { $0.components(separatedBy: " · ") }
        .map { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }
        .joined(separator: "\u{00A0}· ")
}

/// One finished game: who, the rules, the score.
struct GameRow: View {
    let game: ChallengeGame
    var showsOpponent = false

    var body: some View {
        HStack(spacing: Space.m) {
            outcomeBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(showsOpponent ? "You vs \(game.opponentName)" : game.setup.summary)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(showsOpponent
                     ? joinedKeepingPhrases([game.setup.summary, game.playedAt.formatted(.relative(presentation: .named))])
                     : game.playedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: Space.s)
            Text("\(game.myPoints.formatted())–\(game.theirPoints.formatted())")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var outcomeBadge: some View {
        let (letter, fill, label): (String, Color, String) = switch game.outcome {
        case .won: ("W", Theme.correct, "Won")
        case .lost: ("L", Theme.wrong, "Lost")
        case .tied: ("T", Theme.muted, "Tied")
        }
        return Text(letter)
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(fill))
            .accessibilityLabel(label)
    }
}

// MARK: Friend detail

/// Everything about you and one friend: record, stats, games in progress,
/// and every finished game.
struct FriendDetailView: View {
    let friend: Friend

    @Environment(GameCenter.self) private var gameCenter
    @State private var editingRules = false

    var body: some View {
        let stats = gameCenter.history.stats(against: friend.id)
        let record = gameCenter.rivalries.record(against: friend.id)
        let games = gameCenter.history.games(against: friend.id)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header(record: record)

                if stats.played > 0 {
                    StatStrip(items: [
                        .init(label: "Your avg", value: stats.averageMine.formatted(), systemImage: "person.fill"),
                        .init(label: "Their avg", value: stats.averageTheirs.formatted(), systemImage: "person"),
                        .init(label: "Best win", value: stats.biggestWin.map { "+\($0.formatted())" } ?? "–",
                              systemImage: "arrow.up.right"),
                        .init(label: "Run", value: stats.runLabel ?? "–", systemImage: "flame.fill"),
                    ])
                }

                challengeButtons

                ChallengeSection(title: "In progress", items: gameCenter.openChallenges(with: friend.id))

                if games.isEmpty {
                    Text("No finished games with \(friend.name) yet. Games count once you've both played.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: Space.s) {
                        SectionLabel("History")
                        VStack(spacing: 0) {
                            ForEach(Array(games.enumerated()), id: \.element.id) { i, game in
                                if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                                GameRow(game: game)
                            }
                        }
                        .padding(.horizontal, Theme.cardPadding)
                        .padding(.vertical, Space.xs)
                        .card()
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $editingRules) {
            ChallengeSetupSheet(startTitle: "Challenge \(friend.name)") {
                gameCenter.challenge(friendID: friend.id)
            }
        }
    }

    private func header(record: HeadToHead?) -> some View {
        HStack(spacing: Space.l) {
            PlayerBadge(name: friend.name, size: 64)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("You vs \(friend.name)")
                    .font(Theme.display(.title2))
                    .fixedSize(horizontal: false, vertical: true)
                if let record, record.played > 0 {
                    HStack(spacing: Space.m) {
                        tally(record.wins, "Wins", Theme.correct)
                        tally(record.losses, "Losses", Theme.wrong)
                        if record.ties > 0 { tally(record.ties, "Ties", Theme.muted) }
                    }
                } else {
                    Text("No record yet").font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.cardPadding)
        .card(drop: 4)
    }

    private func tally(_ n: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(n.formatted()).font(Theme.display(.title)).foregroundStyle(color)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var challengeButtons: some View {
        HStack(spacing: Space.s) {
            Button { gameCenter.challenge(friendID: friend.id) } label: {
                Label("Challenge", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .accessibilityHint(gameCenter.nextSetup.summary)
            Button { editingRules = true } label: {
                Label("Rules", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .padding(.horizontal, Space.l)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
        }
    }
}

// MARK: Challenge rules

/// Pick the rules for the next challenge: mode, level, category, length,
/// clock and power-ups. Kept for next time.
struct ChallengeSetupSheet: View {
    let startTitle: String
    let onStart: () -> Void

    @Environment(GameCenter.self) private var gameCenter
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private static let mixed = "Mixed"

    var body: some View {
        @Bindable var gameCenter = gameCenter
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    presets

                    VStack(alignment: .leading, spacing: Space.m) {
                        OptionRow(label: "Mode", options: GameMode.allCases,
                                  selection: $gameCenter.nextSetup.mode, title: \.title, inverted: true)
                        Text(gameCenter.nextSetup.mode.summary)
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        OptionRow(label: "Level", options: Difficulty.allCases,
                                  selection: $gameCenter.nextSetup.difficulty, title: \.title, inverted: true)
                        if gameCenter.nextSetup.mode == .classic {
                            OptionRow(label: "Length", options: ChallengeSetup.lengths,
                                      selection: $gameCenter.nextSetup.length, title: \.description, inverted: true)
                        }
                        OptionRow(label: "Power-ups", options: ChallengeSetup.powerUpLimits,
                                  selection: $gameCenter.nextSetup.powerUpLimit, title: \.description, inverted: true)
                        Toggle(isOn: Binding(get: { !gameCenter.nextSetup.hasClock },
                                             set: { gameCenter.nextSetup.isTimed = !$0 })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No clock").font(.subheadline.weight(.semibold))
                                Text(gameCenter.nextSetup.mode == .speed
                                     ? "Speed round is always against the clock."
                                     : "Both of you get as long as you like on each question.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .disabled(gameCenter.nextSetup.mode == .speed)
                    }
                    .padding(Theme.cardPadding)
                    .card()

                    VStack(alignment: .leading, spacing: Space.s) {
                        SectionLabel("Category")
                        OptionRow(label: "Topic", options: [Self.mixed] + store.bank.categories,
                                  selection: Binding(get: { gameCenter.nextSetup.category ?? Self.mixed },
                                                     set: { gameCenter.nextSetup.category = $0 == Self.mixed ? nil : $0 }),
                                  title: \.self, inverted: true)
                    }
                    .padding(Theme.cardPadding)
                    .card()

                    Text("Your friend plays the exact same questions under these rules.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, Space.m)
            }
            .background(Theme.paper)
            .navigationTitle("Challenge rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset") { gameCenter.nextSetup = .standard }
                        .disabled(!gameCenter.nextSetup.isCustom)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    Task {
                        // Let the sheet close before Game Center's picker opens.
                        try? await Task.sleep(for: .milliseconds(450))
                        onStart()
                    }
                } label: {
                    Label(startTitle, systemImage: "paperplane.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, Space.m)
                .background(Theme.paper)
            }
            .onChange(of: gameCenter.nextSetup) { _, new in
                let clean = new.sanitized()
                if clean != new { gameCenter.nextSetup = clean }
            }
        }
        .presentationDetents([.large])
    }

    /// One-tap starting points.
    private var presets: some View {
        let options: [(String, String, ChallengeSetup)] = [
            ("Standard", "list.number", .standard),
            ("Quick 5", "hare.fill", ChallengeSetup(length: 5)),
            ("Brain buster", "brain.head.profile", ChallengeSetup(difficulty: .hard, length: 15, powerUpLimit: 0)),
            ("Speed duel", "stopwatch.fill", ChallengeSetup(mode: .speed)),
            ("Survival", "heart.fill", ChallengeSetup(mode: .survival, powerUpLimit: 3)),
            ("Chill", "tortoise.fill", ChallengeSetup(difficulty: .easy, isTimed: false)),
        ]
        return VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Quick picks")
            FlowLayout(spacing: 6) {
                ForEach(options, id: \.0) { option in
                    let on = gameCenter.nextSetup == option.2
                    Button { gameCenter.nextSetup = option.2 } label: {
                        Label(option.0, systemImage: option.1)
                            .labelStyle(CompactLabelStyle())
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.accent : Theme.card,
                                                   foreground: on ? .white : Theme.ink,
                                                   shape: AnyShape(Theme.pill),
                                                   depth: on ? 2 : 3))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

#Preview("Friends hub") {
    let store = PlayerStore.preview
    NavigationStack { FriendsView() }
        .environment(store)
        .environment(GameCenter(store: store, demo: true))
}
