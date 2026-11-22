import SwiftUI
import TriviaKit

/// The Friends tab: a social hub over Game Center. Three sections:
/// challenges (start one with your own rules, whose turn it is, rematch),
/// friends-only leaderboards (today's Daily and lifetime stats), and your
/// friends with head-to-head history against each.
struct FriendsView: View {
    enum Section: String, CaseIterable, Identifiable {
        case play = "Challenges"
        case boards = "Leaderboards"
        case friends = "Friends"
        var id: String { rawValue }
    }

    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.dynamicTypeSize) private var typeSize
    @SceneStorage("friends.section") private var section: Section = .play
    @State private var editingRules = false
    @State private var pickingGroup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Friends")
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)

                switch gameCenter.auth {
                case .checking:
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                case .signedOut:
                    signInCard
                case .restricted:
                    notice("Multiplayer is turned off",
                           "Screen Time or a device profile blocks multiplayer games. Solo rounds still work.")
                case .signedIn:
                    Picker("Section", selection: $section) {
                        ForEach(Section.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    if let loadError = gameCenter.loadError, section != .boards {
                        loadErrorBanner(loadError)
                    }
                    switch section {
                    case .play:
                        challengeCard
                        lobby
                    case .boards:
                        FriendBoardsView()
                    case .friends:
                        FriendsListView()
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.m)
            .readableWidth()
        }
        .themeBackground()
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await gameCenter.refresh()
            await gameCenter.loadFriends()
        }
        .task {
            await gameCenter.refresh()
            await gameCenter.loadFriends()
        }
        .sheet(isPresented: $editingRules) {
            ChallengeSetupSheet(startTitle: "Pick friends") { gameCenter.newChallenge() }
        }
        .sheet(isPresented: $pickingGroup) {
            FriendPickerSheet(
                title: "Group match",
                note: "Everyone plays the same questions under your rules (\(gameCenter.nextSetup.summary)). Highest score wins.",
                limit: ChallengeData.maxPlayers - 1,
                startTitle: { n in n == 1 ? "Challenge 1 friend" : "Start a squad of \(n + 1)" }
            ) { ids in
                Task { await gameCenter.startMatch(with: ids) }
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { gameCenter.errorMessage != nil },
                                    set: { if !$0 { gameCenter.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(gameCenter.errorMessage ?? "")
        }
    }

    // MARK: Cards

    private var challengeCard: some View {
        // Same shape as Home's mode card: text with the action beside it,
        // stacking at accessibility sizes.
        let setup = gameCenter.nextSetup
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
        return VStack(alignment: .leading, spacing: Space.m) {
            layout {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Take turns")
                        .eyebrow()
                        .opacity(0.9)
                    Text("Challenge friends.")
                        .font(Theme.display(.title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("One friend or a whole group. You play first, they play the same questions when they like. Highest score wins.")
                        .font(.footnote)
                        .opacity(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { gameCenter.newChallenge() } label: {
                    Label("New", systemImage: "plus")
                        .font(.title3.bold())
                        .padding(.horizontal, Space.l)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
                .accessibilityLabel("New challenge")
                .accessibilityHint(setup.summary)
            }
            Button { pickingGroup = true } label: {
                Label("Group match", systemImage: "person.3.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.chunky(fill: .white, foreground: Theme.ink, capsule: true))
            .accessibilityHint("Pick up to \(ChallengeData.maxPlayers - 1) friends to play the same round")
            // The rules the next challenge uses, one tap to change.
            Button { editingRules = true } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "slider.horizontal.3").accessibilityHidden(true)
                    Text(setup.summary)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Space.s)
                    Text("Rules").font(.footnote.bold())
                    Image(systemName: "chevron.right").font(.caption.bold()).accessibilityHidden(true)
                }
                .padding(.horizontal, Space.m)
                .frame(minHeight: 40)
                .background(Theme.pill.fill(.white.opacity(0.16)))
                .contentShape(Theme.pill)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Challenge rules: \(setup.summary)")
            .accessibilityHint("Change difficulty, length, mode and more")
        }
        .foregroundStyle(.white)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.accent, radius: Theme.cardRadius, drop: 5)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Sign in to Game Center")
                .font(Theme.display(.title2))
            Text("Challenges, friends, leaderboards and head-to-head records use your Game Center account. No new account, no ads.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button { gameCenter.signIn() } label: {
                Text("Sign in").font(.headline).padding(.horizontal, 24).padding(.vertical, 10)
            }
            .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            .padding(.top, 4)
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(drop: 4)
    }

    private func loadErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.wrong)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry") { Task { await gameCenter.refresh() } }
                .font(.subheadline.bold())
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.cardPadding)
        .card()
    }

    private func notice(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Lobby

    @ViewBuilder private var lobby: some View {
        let items = gameCenter.challenges
        let yourTurn = items.filter { $0.status == .yourTurn || $0.status == .invited }
        let waiting = items.filter { [.theirTurn, .findingOpponent, .declined, .needsUpdate].contains($0.status) }
        let finished = items.filter(\.isFinished)

        if items.isEmpty && gameCenter.isLoading {
            ProgressView("Loading challenges…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if items.isEmpty && gameCenter.loadError == nil {
            Text("No challenges yet. Start one above, and it shows up here.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        ChallengeSection(title: "Your turn", items: yourTurn)
        ChallengeSection(title: "Waiting on them", items: waiting)
        ChallengeSection(title: "Finished", items: Array(finished.prefix(10)))
    }
}

/// A titled list of challenge rows.
struct ChallengeSection: View {
    let title: String
    let items: [ChallengeItem]

    @Environment(GameCenter.self) private var gameCenter

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel(title)
                ForEach(items) { item in
                    ChallengeRow(item: item,
                                 record: item.opponentID.flatMap(gameCenter.rivals.record(for:)))
                }
            }
        }
    }
}

// MARK: Row

private struct ChallengeRow: View {
    let item: ChallengeItem
    let record: RivalRecord?

    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirmingRemove = false
    @State private var inviting = false

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            if item.isFinished {
                // Tap a finished row to see both scores again.
                Button { Task { await gameCenter.open(item) } } label: { info }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows the result")
            } else {
                info
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
            action
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Space.m)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contextMenu {
            if canInvite {
                Button(item.isGroup ? "Invite more friends" : "Make it a group match", systemImage: "person.badge.plus") {
                    inviting = true
                }
            }
            if item.isFinished, gameCenter.archive.match(item.id) != nil {
                Button("Match breakdown", systemImage: "list.bullet.rectangle") { gameCenter.review(item.id) }
            }
            Button(removeTitle, systemImage: "xmark.circle", role: .destructive) { confirmingRemove = true }
        }
        .sheet(isPresented: $inviting) {
            FriendPickerSheet(
                title: "Invite to this match",
                note: "They play the same questions. Everyone's score so far carries over.",
                excluded: Set(item.seats.map(\.id)),
                limit: ChallengeData.maxPlayers - item.seats.count,
                startTitle: { n in n == 1 ? "Invite 1 friend" : "Invite \(n) friends" }
            ) { ids in
                Task { await gameCenter.invite(ids, into: item.id) }
            }
        }
        .confirmationDialog(removeTitle + "?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button(removeTitle, role: .destructive) { Task { await gameCenter.remove(item) } }
        } message: {
            Text(removeMessage)
        }
    }

    private var canInvite: Bool {
        !item.isFinished && item.status != .needsUpdate && item.status != .declined
            && item.setup?.allowsInvites != false && item.seats.count < ChallengeData.maxPlayers
    }

    @ViewBuilder private var avatar: some View {
        if item.isGroup {
            AvatarStack(seats: item.others, size: 30, limit: 3)
        } else {
            PlayerAvatar(name: item.opponentName, card: item.card, size: 44)
        }
    }

    private var info: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if item.isGroup {
                        Image(systemName: "person.3.fill").font(.caption.bold()).foregroundStyle(Theme.accent)
                            .accessibilityLabel("Group match")
                    }
                    Text(item.opponentName).font(.headline).lineLimit(1)
                    if let record, record.played > 0, !item.isGroup { RecordChip(record: record) }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let setup = item.setup, setup.isCustom {
                    Text(setup.summary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let ago = item.updated.formatted(.relative(presentation: .named))
        if item.isGroup { return groupSubtitle(ago: ago) }
        switch item.status {
        case .invited:
            return item.theirPoints.map { "Challenged you · scored \($0.formatted())" } ?? "Challenged you"
        case .yourTurn:
            return item.theirPoints.map { "Score to beat: \($0.formatted())" } ?? "Your turn to play"
        case .theirTurn:
            return item.myPoints.map { "You scored \($0.formatted()) · \(ago)" } ?? "Their turn · \(ago)"
        case .findingOpponent:
            return "Finding an opponent…"
        case .declined:
            return "Declined the challenge"
        case .needsUpdate:
            return "Update Quizio to play this one"
        case .finished where item.theirPoints == nil:
            return "\(item.opponentName) didn't play · not counted"
        case .finished where item.myPoints == nil:
            return "You didn't play · not counted"
        case .finished(let outcome):
            let score = "\((item.myPoints ?? 0).formatted())–\((item.theirPoints ?? 0).formatted())"
            switch outcome {
            case .won: return "You won \(score)"
            case .lost: return "You lost \(score)"
            case .tied: return "Tied \(score)"
            case nil: return "Ended"
            }
        }
    }

    private func groupSubtitle(ago: String) -> String {
        let played = item.others.filter { $0.state == .played }.count
        switch item.status {
        case .invited: return "Invited you · \(played) of \(item.others.count) played"
        case .yourTurn:
            return item.theirPoints.map { "Your turn · top score \($0.formatted())" } ?? "Your turn to play"
        case .theirTurn:
            if let up = item.upNext { return "\(up.name) is up · \(played + (item.myPoints == nil ? 0 : 1)) of \(item.seats.count) played" }
            return "Waiting on the group · \(ago)"
        case .findingOpponent: return "Filling seats…"
        case .declined: return "Everyone passed"
        case .needsUpdate: return "Update Quizio to play this one"
        case .finished:
            guard item.myPoints != nil, let place = item.place else { return "You didn't play · \(ago)" }
            return place == 1 ? "You won · \((item.myPoints ?? 0).formatted()) pts" : "You placed #\(place) of \(item.seats.count) · \((item.myPoints ?? 0).formatted()) pts"
        }
    }

    @ViewBuilder private var action: some View {
        switch item.status {
        case .invited, .yourTurn:
            Button { Task { await gameCenter.open(item) } } label: {
                Text("Play").font(.headline).lineLimit(1).padding(.horizontal, Space.l).frame(minHeight: 44)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .fixedSize()
            .accessibilityHint(item.isGroup ? "Plays your turn in the group match" : "Plays your turn against \(item.opponentName)")
        case .finished(let outcome) where outcome != nil:
            Button { Task { await gameCenter.rematch(item.id) } } label: {
                Text("Rematch").font(.headline).lineLimit(1).padding(.horizontal, 16).frame(minHeight: 44)
            }
            .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            .fixedSize()
            .accessibilityHint("Starts a new challenge with \(item.opponentName)")
        default:
            EmptyView()
        }
    }

    private var removeTitle: String {
        switch item.status {
        case .invited: "Decline"
        case .yourTurn, .theirTurn, .findingOpponent: "Forfeit"
        default: "Remove"
        }
    }

    private var removeMessage: String {
        if item.isGroup, [.yourTurn, .theirTurn, .findingOpponent].contains(item.status) {
            return "You'll be out of this group match."
        }
        return switch item.status {
        case .invited: "\(item.opponentName) will see that you passed."
        case .yourTurn, .theirTurn, .findingOpponent: "This counts as a loss against \(item.opponentName)."
        default: "Clears it from your list. Your head-to-head record stays."
        }
    }
}

/// "3–1" with a small trophy, for head-to-head records.
struct RecordChip: View {
    let record: RivalRecord

    var body: some View {
        Label(record.summary, systemImage: "trophy.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.pill.fill(Theme.paper))
            .overlay(Theme.pill.stroke(Theme.line, lineWidth: 1))
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Record \(record.wins) wins, \(record.losses) losses"
                                + (record.ties > 0 ? ", \(record.ties) ties" : ""))
    }
}

#Preview {
    let store = PlayerStore.preview
    NavigationStack { FriendsView() }
        .environment(store)
        .environment(GameCenter(store: store, demo: true))
}
