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
        for rival in rivals.sorted where seen.insert(rival.id).inserted {
            rows.append(Friend(id: rival.id, name: rival.name))
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
        challenges.filter { $0.includes(friendID) && !$0.isFinished }
    }

    // MARK: Leaderboards

    /// A board's scores as last loaded. `previous` is yesterday's Daily
    /// or last week's event.
    func boardState(_ board: FriendBoard, previous: Bool = false) -> BoardState? {
        previous ? previousBoards[board] : boards[board]
    }

    private func setBoard(_ board: FriendBoard, previous: Bool, _ state: BoardState) {
        if previous { previousBoards[board] = state } else { boards[board] = state }
    }

    /// Loads friends' scores on one board, you included. For the Daily and
    /// Weekly boards, `previous` loads yesterday's or last week's instead.
    func loadBoard(_ board: FriendBoard, previous: Bool = false) async {
        if isDemo { return }
        guard auth == .signedIn else { return }
        if case .loaded? = boardState(board, previous: previous) {} else { setBoard(board, previous: previous, .loading) }
        do {
            guard let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [board.leaderboardID]).first else {
                setBoard(board, previous: previous,
                         .failed("This leaderboard isn't live yet. Check back after the next update."))
                return
            }
            var all: [GKLeaderboard.Entry] = []
            if let context = board.context(today: store.today, previous: previous) {
                // Game Center's periods start at a fixed UTC time, not local
                // midnight, so a day's (or week's) scores can sit in this
                // occurrence or the one before. Read both and keep only
                // scores tagged with the period we want.
                var occurrences = [leaderboard]
                if let prior = try? await leaderboard.loadPreviousOccurrence() { occurrences.append(prior) }
                var best: [String: GKLeaderboard.Entry] = [:]
                for occurrence in occurrences {
                    let (local, entries, _) = try await occurrence.loadEntries(
                        for: .friendsOnly, timeScope: .allTime, range: NSRange(location: 1, length: 50))
                    for e in entries + [local].compactMap({ $0 }) where e.context == context {
                        let id = e.player.gamePlayerID
                        if let kept = best[id], kept.score >= e.score { continue }
                        best[id] = e
                    }
                }
                all = Array(best.values)
            } else {
                let (local, entries, _) = try await leaderboard.loadEntries(
                    for: .friendsOnly, timeScope: .allTime, range: NSRange(location: 1, length: 50))
                all = entries
                if let local, !all.contains(where: { $0.player.gamePlayerID == local.player.gamePlayerID }) {
                    all.append(local)
                }
            }
            all.sort { $0.score != $1.score ? $0.score > $1.score : $0.rank < $1.rank }
            let me = localPlayerID
            setBoard(board, previous: previous, .loaded(all.enumerated().map { i, e in
                BoardEntry(id: e.player.gamePlayerID, rank: i + 1, name: e.player.displayName,
                           value: e.score, isMe: e.player.gamePlayerID == me)
            }))
        } catch {
            setBoard(board, previous: previous, .failed(Self.friendly(error, doing: "load this leaderboard")))
        }
    }

    // MARK: Posting scores

    /// Posts anything that changed since last time: the Daily right after
    /// it's played (timed only), this week's best event round after an
    /// event round, and the lifetime boards. Cheap to call often.
    func postScores(after kind: RoundKind?) {
        guard !isDemo, auth == .signedIn else { return }
        let progress = store.progress
        let today = store.today
        var posts: [(FriendBoard, Int, Int)] = []
        if case .daily(let day)? = kind, day == today,
           let points = FriendBoard.dailyScore(progress.dailies[day]) {
            posts.append((.daily, points, day.ordinal))
        }
        if case .event(let event, let week)? = kind, week == today.weekIndex,
           let best = FriendBoard.weeklyScore(progress.eventProgress(event, week: week)) {
            posts.append((.weekly, best, week))
        }
        for board in FriendBoard.allCases {
            guard let value = board.value(progress: progress, today: today),
                  value != lastPosted(board) else { continue }
            posts.append((board, value, 0))
        }
        guard !posts.isEmpty else { return }
        Task {
            for (board, value, context) in posts {
                do {
                    try await GKLeaderboard.submitScore(value, context: context, player: GKLocalPlayer.local,
                                                        leaderboardIDs: [board.leaderboardID])
                    if !board.isRecurring { setLastPosted(value, for: board) }
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
            case .weekly: [1_620, 1_450, 1_200, 1_040, 880]
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
            if board.isRecurring {
                let earlier = people.indices.map { people[($0 + i + 2) % people.count] }
                previousBoards[board] = .loaded(zip(earlier, base).enumerated().map { rank, pair in
                    BoardEntry(id: pair.0.0, rank: rank + 1, name: pair.0.1, value: pair.1 - 90, isMe: pair.0.0 == me)
                })
            }
        }
    }
}
