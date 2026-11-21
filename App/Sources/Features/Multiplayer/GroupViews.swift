import SwiftUI
import TriviaKit

// MARK: Match header

/// The top of a match intro: the other player's full Player Card in a
/// head-to-head, or the whole group's avatars (tap any to see their card).
struct MatchHeader: View {
    let round: ChallengeRound

    var body: some View {
        VStack(spacing: Space.m) {
            SectionLabel(round.isGroup ? "Group match · \(round.seats.count) players" : "Challenge")
            if round.isGroup {
                Text("You vs the group")
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                SeatRow(seats: round.seats)
            } else {
                Text("You vs \(round.opponentName)")
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                if let other = round.others.first, let card = other.card {
                    PlayerCardView(look: CardLook(shared: card))
                } else {
                    HStack(spacing: 14) {
                        PlayerAvatar(name: "You", card: round.seats.first?.card, size: 56)
                        Text("vs").font(Theme.display(.title2)).foregroundStyle(Theme.muted)
                        PlayerAvatar(name: round.opponentName, card: nil, size: 56)
                    }
                }
            }
        }
    }
}

/// Everyone in a group, with who's played and whose turn it is. Tap an
/// avatar for the full card.
struct SeatRow: View {
    let seats: [MatchSeat]
    var size: CGFloat = 52

    var body: some View {
        FlowLayout(spacing: Space.m) {
            ForEach(seats) { seat in
                VStack(spacing: Space.xs) {
                    PlayerAvatar(name: seat.name, card: seat.card, size: size, badge: badge(seat))
                    Text(seat.name)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Text(caption(seat))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(seat.state == .up ? Theme.accent : Theme.muted)
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.ink)
                .frame(width: size + 26)
                .opacity(seat.state == .out ? 0.45 : 1)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func badge(_ seat: MatchSeat) -> PlayerAvatar.Badge? {
        switch seat.state {
        case .played: .check
        case .up, .waiting: seat.isMe ? nil : .waiting
        case .out: nil
        }
    }

    private func caption(_ seat: MatchSeat) -> String {
        switch seat.state {
        case .played: seat.points.map { $0.formatted() } ?? "Played"
        case .up: seat.isMe ? "Your turn" : "Playing now"
        case .waiting: "Up soon"
        case .out: "Out"
        }
    }
}

// MARK: Invites

/// "Invite friends" on a match: opens the picker, then moves the match to
/// a bigger group with everyone's scores so far.
struct InviteButton: View {
    let round: ChallengeRound

    @Environment(GameCenter.self) private var gameCenter
    @State private var picking = false

    var body: some View {
        Button { picking = true } label: {
            Label(round.isGroup ? "Invite more friends" : "Make it a group match", systemImage: "person.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
        .accessibilityHint("Adds friends to this match. Scores so far carry over.")
        .sheet(isPresented: $picking) {
            FriendPickerSheet(
                title: "Invite to this match",
                note: "They play the same questions. Everyone's score so far carries over.",
                excluded: Set(round.seats.map(\.id)),
                limit: ChallengeData.maxPlayers - round.seats.count,
                startTitle: { n in n == 1 ? "Invite 1 friend" : "Invite \(n) friends" }
            ) { ids in
                Task { await gameCenter.invite(ids, into: round.id) }
            }
        }
    }
}

/// Pick friends for a group match: a grid of avatars to tap, with your
/// squad shown at the top as it fills up.
struct FriendPickerSheet: View {
    let title: String
    let note: String
    var excluded: Set<String> = []
    /// Most friends you can pick.
    let limit: Int
    let startTitle: (Int) -> String
    let onStart: ([String]) -> Void

    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.dismiss) private var dismiss
    @State private var picked: [String] = []

    private var friends: [Friend] { gameCenter.invitable(excluding: excluded) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    squad
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if friends.isEmpty {
                        empty
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Space.m)], spacing: Space.m) {
                            ForEach(friends) { friend in tile(friend) }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, Space.m)
                .readableWidth()
            }
            .themeBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let ids = picked
                    dismiss()
                    Task {
                        // Let the sheet close before the match opens.
                        try? await Task.sleep(for: .milliseconds(450))
                        onStart(ids)
                    }
                } label: {
                    Label(picked.isEmpty ? "Pick friends" : startTitle(picked.count), systemImage: "paperplane.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                .disabled(picked.isEmpty)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, Space.m)
                .background(Theme.paper)
            }
            .task { await gameCenter.loadFriends() }
        }
        .presentationDetents([.large])
    }

    /// You plus everyone picked so far, popping in as they're added.
    private var squad: some View {
        let names = Dictionary(friends.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        return VStack(spacing: Space.s) {
            HStack(spacing: -12) {
                PlayerAvatar(name: "You", card: gameCenter.localPlayerInfo.card, size: 52, expands: false)
                ForEach(picked, id: \.self) { id in
                    PlayerAvatar(name: names[id] ?? "Friend", card: nil, size: 52, expands: false)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: picked)
            Text(squadLabel)
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.snappy, value: picked.count)
            Text(picked.count >= limit ? "That's a full match." : "Up to \(limit) more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.cardPadding)
        .card(drop: 4)
        .accessibilityElement(children: .combine)
    }

    private var squadLabel: String {
        let total = picked.count + 1 + excluded.subtracting([gameCenter.localPlayerID]).count
        switch total {
        case ...1: return "Who's playing?"
        case 2: return "Head-to-head"
        default: return "Squad of \(total)"
        }
    }

    private func tile(_ friend: Friend) -> some View {
        let on = picked.contains(friend.id)
        let full = !on && picked.count >= limit
        return Button {
            if on { picked.removeAll { $0 == friend.id } } else if !full { picked.append(friend.id) }
        } label: {
            VStack(spacing: Space.xs) {
                PlayerAvatar(name: friend.name, card: nil, size: 48, badge: on ? .check : nil, expands: false)
                Text(friend.name)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.chip(selected: on, depth: on ? 2 : 3))
        .disabled(full)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder private var empty: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(gameCenter.friendsAccess == .denied
                 ? "Turn on friends access for Quizio in Settings › Game Center › Friends List to pick friends here."
                 : "Your Game Center friends show up here.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if gameCenter.friendsAccess == .notDetermined {
                Button { Task { await gameCenter.loadFriends(ask: true) } } label: {
                    Text("Show friends").font(.subheadline.bold()).padding(.horizontal, Space.l).frame(minHeight: 40)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
