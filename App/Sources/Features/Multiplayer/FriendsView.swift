import SwiftUI
import TriviaKit

/// The Friends lobby: start a challenge, see whose turn it is, rematch, and
/// your head-to-head record with each friend. Async "take turns" play over
/// Game Center; live rounds come later.
struct FriendsView: View {
    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Friends")
                    .font(Theme.display(.largeTitle))
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
                    if let loadError = gameCenter.loadError {
                        loadErrorBanner(loadError)
                    }
                    challengeCard
                    lobby
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await gameCenter.refresh() }
        .task { await gameCenter.refresh() }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Take turns")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .kerning(1)
                .opacity(0.9)
            Text("Challenge\na friend.")
                .font(Theme.display(.largeTitle))
            Text("You play 10 questions, then they play the same 10 whenever they like. Highest score wins.")
                .font(.subheadline)
                .opacity(0.92)
                .fixedSize(horizontal: false, vertical: true)
            Button { gameCenter.newChallenge() } label: {
                Label("New challenge", systemImage: "plus")
                    .font(.title3.bold())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.accent, radius: 28, drop: 6)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Sign in to Game Center")
                .font(Theme.display(.title2))
            Text("Challenges, friends and head-to-head records use your Game Center account. No new account, no ads.")
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
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
        .padding(16)
        .card(radius: 20)
    }

    private func notice(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
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
        section("Your turn", yourTurn)
        section("Waiting on them", waiting)
        section("Finished", Array(finished.prefix(10)))
        rivals
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [ChallengeItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title)
                ForEach(items) { item in
                    ChallengeRow(item: item,
                                 record: item.opponentID.flatMap(gameCenter.rivalries.record(against:)))
                }
            }
        }
    }

    @ViewBuilder private var rivals: some View {
        let rivals = gameCenter.rivalries.rivals
        if !rivals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Head to head")
                VStack(spacing: 0) {
                    ForEach(Array(rivals.enumerated()), id: \.element.id) { i, rival in
                        if i > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                        HStack(spacing: 12) {
                            PlayerBadge(name: rival.record.displayName, size: 36)
                            Text(rival.record.displayName).font(.headline)
                            Spacer(minLength: 8)
                            RecordChip(record: rival.record)
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .card()
            }
        }
    }
}

// MARK: Row

private struct ChallengeRow: View {
    let item: ChallengeItem
    let record: HeadToHead?

    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirmingRemove = false

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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 20)
        .contextMenu {
            Button(removeTitle, systemImage: "xmark.circle", role: .destructive) { confirmingRemove = true }
        }
        .confirmationDialog(removeTitle + "?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button(removeTitle, role: .destructive) { Task { await gameCenter.remove(item) } }
        } message: {
            Text(removeMessage)
        }
    }

    private var info: some View {
        HStack(spacing: 12) {
            PlayerBadge(name: item.opponentName)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.opponentName).font(.headline).lineLimit(1)
                    if let record, record.played > 0 { RecordChip(record: record) }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let ago = item.updated.formatted(.relative(presentation: .named))
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

    @ViewBuilder private var action: some View {
        switch item.status {
        case .invited, .yourTurn:
            Button { Task { await gameCenter.open(item) } } label: {
                Text("Play").font(.headline).lineLimit(1).padding(.horizontal, 20).frame(minHeight: 44)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .fixedSize()
            .accessibilityHint("Plays your turn against \(item.opponentName)")
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
        switch item.status {
        case .invited: "\(item.opponentName) will see that you passed."
        case .yourTurn, .theirTurn, .findingOpponent: "This counts as a loss against \(item.opponentName)."
        default: "Clears it from your list. Your head-to-head record stays."
        }
    }
}

/// "3–1" with a small trophy, for head-to-head records.
private struct RecordChip: View {
    let record: HeadToHead

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
