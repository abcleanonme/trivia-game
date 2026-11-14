@preconcurrency import GameKit
import SwiftUI
import TriviaKit

/// A Game Center friend, for the Friends list.
struct Friend: Identifiable, Equatable {
    let id: String
    let name: String
}

/// Whether we may read the player's Game Center friends list.
enum FriendsAccess: Equatable {
    case unknown
    /// Not asked yet. Asking shows Apple's prompt.
    case notDetermined
    /// Turned off, or blocked by Screen Time.
    case denied
    case granted
}

/// One row on a friends leaderboard.
struct BoardEntry: Identifiable, Equatable {
    let id: String
    let rank: Int
    let name: String
    let value: Int
    let isMe: Bool
}

enum BoardState: Equatable {
    case loading
    case loaded([BoardEntry])
    /// Not set up in App Store Connect yet, or offline.
    case failed(String)
}

/// The social half of the Friends tab: the friends list, friends-only
/// leaderboards for the Daily and lifetime stats, and posting our scores.
extension GameCenter {
    // MARK: Friends list

    /// Reads the friends list, asking for access the first time if `ask`.
    func loadFriends(ask: Bool = false) async {
        if isDemo { return }
        guard auth == .signedIn else { return }
        let local = GKLocalPlayer.local
        do {
            let status = try await local.loadFriendsAuthorizationStatus()
            switch status {
            case .authorized:
                friendsAccess = .granted
            case .notDetermined:
                friendsAccess = .notDetermined
                guard ask else { return }
            default:
                friendsAccess = .denied
                return
            }
            // Shows Apple's one-time prompt when not determined yet.
            let players = try await local.loadFriends()
            for p in players { knownPlayers[p.gamePlayerID] = p }
            friends = players.map { Friend(id: $0.gamePlayerID, name: $0.displayName) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            friendsAccess = .granted
        } catch {
            if (error as? GKError)?.code == .friendListDenied || (error as? GKError)?.code == .friendListRestricted {
                friendsAccess = .denied
            }
        }
    }

    /// Everyone to show in the Friends list: Game Center friends plus anyone
    /// we've played, with whoever we've played most at the top.
    var friendRows: [Friend] {
        var seen = Set<String>()
        var rows: [Friend] = []
        for opponent in history.opponents where seen.insert(opponent.id).inserted {
            rows.append(Friend(id: opponent.id, name: opponent.name))
        }
        for rival in rivalries.rivals where seen.insert(rival.id).inserted {
            rows.append(Friend(id: rival.id, name: rival.record.displayName))
        }
        for friend in friends where seen.insert(friend.id).inserted {
            rows.append(friend)
        }
        return rows
    }

    /// Opens the friend picker with this friend already chosen, if Game
    /// Center knows them; otherwise the plain picker.
    func challenge(friendID: String) {
        if let player = knownPlayers[friendID] {
            newChallenge(with: [player])
        } else {
            newChallenge()
        }
    }

    /// Challenges in progress with this friend.
    func openChallenges(with friendID: String) -> [ChallengeItem] {
        challenges.filter { $0.opponentID == friendID && !$0.isFinished }
    }

    // MARK: Leaderboards

    /// Loads friends' scores on one board, you included.
    func loadBoard(_ board: FriendBoard) async {
        if isDemo { return }
        guard auth == .signedIn else { return }
        if case .loaded? = boards[board] {} else { boards[board] = .loading }
        do {
            guard let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [board.leaderboardID]).first else {
                boards[board] = .failed("This leaderboard isn't live yet. Check back after the next update.")
                return
            }
            let (local, entries, _) = try await leaderboard.loadEntries(
                for: .friendsOnly, timeScope: .allTime, range: NSRange(location: 1, length: 50))
            var all = entries
            if let local, !all.contains(where: { $0.player.gamePlayerID == local.player.gamePlayerID }) {
                all.append(local)
            }
            // The Daily resets on Game Center's clock, which isn't local
            // midnight everywhere, so keep only scores tagged with today.
            let today = store.today.ordinal
            if board.isDaily { all = all.filter { $0.context == today } }
            all.sort { $0.score != $1.score ? $0.score > $1.score : $0.rank < $1.rank }
            let me = localPlayerID
            boards[board] = .loaded(all.enumerated().map { i, e in
                BoardEntry(id: e.player.gamePlayerID, rank: i + 1, name: e.player.displayName,
                           value: e.score, isMe: e.player.gamePlayerID == me)
            })
        } catch {
            boards[board] = .failed(Self.friendly(error, doing: "load this leaderboard"))
        }
    }

    // MARK: Posting scores

    /// Posts anything that changed since last time: the Daily right after
    /// it's played (timed only), and the lifetime boards. Cheap to call often.
    func postScores(after kind: RoundKind?) {
        guard !isDemo, auth == .signedIn else { return }
        let progress = store.progress
        let today = store.today
        var posts: [(FriendBoard, Int, Int)] = []
        if case .daily(let day)? = kind, day == today,
           let points = FriendBoard.dailyScore(progress.dailies[day]) {
            posts.append((.daily, points, day.ordinal))
        }
        let wins = rivalries.rivals.reduce(0) { $0 + $1.record.wins }
        for board in FriendBoard.allCases {
            guard let value = board.value(progress: progress, today: today, challengeWins: wins),
                  value != lastPosted(board) else { continue }
            posts.append((board, value, 0))
        }
        guard !posts.isEmpty else { return }
        Task {
            for (board, value, context) in posts {
                do {
                    try await GKLeaderboard.submitScore(value, context: context, player: GKLocalPlayer.local,
                                                        leaderboardIDs: [board.leaderboardID])
                    if !board.isDaily { setLastPosted(value, for: board) }
                    if case .loaded? = boards[board] { await loadBoard(board) }
                } catch {
                    // Tried again on the next refresh.
                }
            }
        }
    }

    private func lastPosted(_ board: FriendBoard) -> Int? {
        defaults.object(forKey: "board.posted.\(board.rawValue)") as? Int
    }

    private func setLastPosted(_ value: Int, for board: FriendBoard) {
        defaults.set(value, forKey: "board.posted.\(board.rawValue)")
    }

    // MARK: Demo

    func loadDemoFriends() {
        friendsAccess = .granted
        friends = [Friend(id: "jordan", name: "Jordan"), Friend(id: "maya", name: "Maya"),
                   Friend(id: "priya", name: "Priya"), Friend(id: "sam", name: "Sam")]
        let me = localPlayerID
        let people = [("maya", "Maya"), (me, localPlayerName), ("sam", "Sam"), ("priya", "Priya"), ("jordan", "Jordan")]
        for (i, board) in FriendBoard.allCases.enumerated() {
            let base: [Int] = switch board {
            case .daily: [1_480, 1_310, 1_120, 990, 760]
            case .streak: [21, 12, 9, 4, 1]
            case .challengeWins: [14, 11, 6, 3, 2]
            case .correct: [2_410, 1_980, 1_502, 880, 412]
            case .survival: [38, 27, 22, 15, 9]
            case .speed: [31, 26, 24, 19, 12]
            }
            // Shuffle who leads per board so the demo looks lived in.
            let order = people.indices.map { people[($0 + i) % people.count] }
            boards[board] = .loaded(zip(order, base).enumerated().map { rank, pair in
                BoardEntry(id: pair.0.0, rank: rank + 1, name: pair.0.1, value: pair.1, isMe: pair.0.0 == me)
            })
        }
    }
}
