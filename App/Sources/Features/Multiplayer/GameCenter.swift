@preconcurrency import GameKit
import Observation
import SwiftUI
import TriviaKit
import UIKit

/// One row in the Friends lobby.
struct ChallengeItem: Identifiable, Equatable {
    enum Status: Equatable {
        /// A friend challenged you and you haven't opened it yet.
        case invited
        case yourTurn
        case theirTurn
        /// Auto-match: Game Center is still finding someone.
        case findingOpponent
        case declined
        case finished(ChallengeOutcome?)
        /// Made by a newer version of the app.
        case needsUpdate
    }

    let id: String
    /// The other player in a head-to-head; nil in a group match.
    let opponentID: String?
    /// The other player's name, or a short list of names for a group.
    let opponentName: String
    var status: Status
    var myPoints: Int?
    /// The other player's score, or the best other score in a group.
    var theirPoints: Int?
    var updated: Date
    /// The rules, once the challenger has dealt.
    var setup: ChallengeSetup?
    /// Everyone in the match, you first.
    var seats: [MatchSeat] = []
    /// Your place once a group match is finished.
    var place: Int?

    var isFinished: Bool { if case .finished = status { true } else { false } }
    var isGroup: Bool { seats.count > 2 }
    var others: [MatchSeat] { seats.filter { !$0.isMe } }
    /// Who has the turn now, when it isn't you.
    var upNext: MatchSeat? { others.first { $0.state == .up } }
    var card: SharedCard? { others.first?.card }

    /// Whether this match includes `friendID`.
    func includes(_ friendID: String) -> Bool { seats.contains { $0.id == friendID } }

    /// "Maya", or "Maya, Sam & Priya" for a group.
    static func groupName(_ names: [String]) -> String {
        switch names.count {
        case 0: "Someone new"
        case 1...3: names.formatted(.list(type: .and))
        default: "\(names.prefix(2).joined(separator: ", ")) & \(names.count - 2) more"
        }
    }
}

/// A challenge round to show full screen: the intro, the round itself, or
/// the result of a finished match.
struct ChallengeRound: Identifiable {
    let id: String
    var data: ChallengeData
    /// The other player in a head-to-head; nil in a group match.
    let opponentID: String?
    let opponentName: String
    /// Game Center IDs of everyone still in the match.
    let playerIDs: [String]
    /// Everyone in the match, you first, with their cards.
    var seats: [MatchSeat] = []
    /// Whether the turn is ours now (only then can friends be invited in).
    var isMyTurn = false

    var isGroup: Bool { seats.count > 2 }
    var others: [MatchSeat] { seats.filter { !$0.isMe } }
    func name(of playerID: String) -> String {
        seats.first { $0.id == playerID }?.name ?? (playerID == opponentID ? opponentName : "Player")
    }
    func card(of playerID: String) -> SharedCard? {
        data.player(playerID)?.card ?? seats.first { $0.id == playerID }?.card
    }
    /// Room for more players, and the rules allow it.
    var canInvite: Bool {
        data.allowsInvites && seats.count < ChallengeData.maxPlayers
    }
}

/// Async "challenge a friend" over Game Center turn-based matches.
///
/// One match = one round of the same questions for two players. The
/// challenger deals and plays, then passes the turn; the friend plays and
/// ends the match. All state lives in the match data (see `ChallengeData`),
/// so there is no server of our own. Head-to-head records are kept on this
/// device and rebuilt from finished matches.
@MainActor
@Observable
final class GameCenter: NSObject {
    enum Auth: Equatable {
        case checking
        case signedIn
        case signedOut
        /// Parental controls or MDM block Game Center.
        case restricted
    }

    private(set) var auth: Auth = .checking
    private(set) var challenges: [ChallengeItem] = []
    /// Every finished challenge with both scores, newest first.
    private(set) var history: ChallengeHistory
    /// Recent finished matches with every answer, for breakdowns and replays.
    private(set) var archive: MatchArchive
    /// A finished match's breakdown to show (from history or a lobby row).
    var reviewing: ArchivedMatch?
    /// Rules for the next challenge you start. Remembered between launches.
    var nextSetup: ChallengeSetup {
        didSet { defaults.setEncoded(nextSetup, forKey: Self.setupKey) }
    }

    // Friends hub (see GameCenter+Friends.swift).
    var friends: [Friend] = []
    var friendsAccess: FriendsAccess = .unknown
    var boards: [FriendBoard: BoardState] = [:]
    /// Yesterday's Daily and last week's event (recurring boards only).
    var previousBoards: [FriendBoard: BoardState] = [:]
    private(set) var isLoading = false
    /// Drives the full-screen challenge cover.
    var activeRound: ChallengeRound?
    var errorMessage: String?
    /// Why the lobby couldn't load, shown inline instead of an alert so
    /// being offline doesn't pop up a dialog every time.
    private(set) var loadError: String?

    @ObservationIgnored let store: PlayerStore
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored private var matches: [String: GKTurnBasedMatch] = [:]
    @ObservationIgnored private var signInController: UIViewController?
    @ObservationIgnored private var listening = false
    @ObservationIgnored private var queuedRefresh: Task<Void, Never>?
    @ObservationIgnored private var latestRefresh: Task<Void, Never>?
    /// Matches we're sending a turn for, so a lobby refresh leaves them alone.
    @ObservationIgnored private var busy: Set<String> = []
    @ObservationIgnored private var cache: [String: (stamp: String, data: ChallengeData?)] = [:]
    @ObservationIgnored let isDemo: Bool
    /// Players seen in matches or the friends list, for starting a
    /// challenge with someone straight from their page.
    @ObservationIgnored var knownPlayers: [String: GKPlayer] = [:]
    /// Head-to-heads (and groups) that were turned into a bigger group
    /// match: old match ID to the new one.
    @ObservationIgnored var successors: [String: String] = [:]
    /// Debug demo only: sample head-to-head records, so the demo never
    /// writes into the player's real progress.
    private var demoRivals: RivalryBook?
    private static let historyKey = "challenge.history.v1"
    private static let setupKey = "challenge.setup.v1"
    /// Older builds kept a second copy of head-to-head records here. Read
    /// once at launch for its list of counted matches, then removed.
    private static let legacyRivalriesKey = "rivalries.v1"
    private static let pendingKey = "challenge.pendingTurns.v1"
    /// Turns played but not yet sent, by match ID. Kept on the phone so a
    /// dropped connection never loses a score or lets a round be replayed.
    @ObservationIgnored private var pending: [String: ChallengeTurn] = [:]

    init(store: PlayerStore, defaults: UserDefaults = .standard, demo: Bool = GameCenter.demoRequested) {
        self.store = store
        self.defaults = defaults
        self.isDemo = demo
        history = defaults.decoded(ChallengeHistory.self, forKey: Self.historyKey) ?? ChallengeHistory()
        archive = MatchArchiveFile.load()
        nextSetup = defaults.decoded(ChallengeSetup.self, forKey: Self.setupKey)?.sanitized() ?? .standard
        pending = defaults.decoded([String: ChallengeTurn].self, forKey: Self.pendingKey, using: .challenge) ?? [:]
        if let legacy = defaults.decoded(LegacyRivalries.self, forKey: Self.legacyRivalriesKey) {
            store.markMatchesCounted(legacy.countedMatchIDs)
            defaults.removeObject(forKey: Self.legacyRivalriesKey)
        }
        super.init()
        store.onRoundRecorded = { [weak self] kind in self?.postScores(after: kind) }
        if demo { loadDemo() }
    }

    /// Challenges waiting on us, for the Friends tab badge.
    var yourTurnCount: Int { challenges.filter { $0.status == .yourTurn || $0.status == .invited }.count }

    var localPlayerID: String { isDemo ? "me" : GKLocalPlayer.local.gamePlayerID }

    /// Head-to-head records, kept with the rest of the player's progress.
    var rivals: RivalryBook { demoRivals ?? store.progress.rivals }
    var localPlayerName: String { isDemo ? "You" : GKLocalPlayer.local.displayName }

    // MARK: Sign in

    /// Call once at launch. Game Center shows its own banner or sign-in sheet.
    func authenticate() {
        guard !isDemo else { return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in self?.handleAuth(controller: controller, error: error) }
        }
    }

    private func handleAuth(controller: UIViewController?, error: (any Error)?) {
        let player = GKLocalPlayer.local
        if let controller {
            signInController = controller
            auth = .signedOut
        } else if player.isAuthenticated {
            signInController = nil
            auth = player.isMultiplayerGamingRestricted ? .restricted : .signedIn
            if !listening {
                player.register(self)
                listening = true
            }
            Task { await refresh() }
        } else {
            auth = .signedOut
        }
    }

    /// Shows Game Center's sign-in sheet if it gave us one, otherwise sends
    /// the player to Settings, where Game Center sign-in lives.
    func signIn() {
        if let signInController {
            present(signInController)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: Lobby

    /// Reloads the lobby from Game Center. Calls that arrive while a load is
    /// running are folded into one follow-up load, so overlapping refreshes
    /// (turn events, pull to refresh, coming back to the app) can't race
    /// each other or close out the same match twice.
    func refresh() async {
        guard !isDemo, auth == .signedIn else { return }
        if let queued = queuedRefresh { return await queued.value }
        let running = latestRefresh
        let task = Task { @MainActor [weak self] in
            await running?.value
            guard let self else { return }
            self.queuedRefresh = nil
            await self.reload()
        }
        queuedRefresh = task
        latestRefresh = task
        await task.value
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        await sendPendingTurns()
        do {
            let loaded = try await GKTurnBasedMatch.loadMatches()
            var items: [ChallengeItem] = []
            var byID: [String: GKTurnBasedMatch] = [:]
            var loadedData: [String: ChallengeData] = [:]
            for match in loaded {
                byID[match.matchID] = match
                if let data = await challengeData(of: match) {
                    loadedData[match.matchID] = data
                    if let old = data.groupFrom { successors[old] = match.matchID }
                }
            }
            for match in loaded {
                let data = loadedData[match.matchID]
                // A match that moved into a group match: close it out if
                // it's ours to close, and leave it off the list.
                if let next = data?.movedTo ?? successors[match.matchID] {
                    await closeSuperseded(match, data: data, movedTo: next)
                    continue
                }
                if let item = await item(for: match, data: data) { items.append(item) }
            }
            matches = byID
            challenges = items.sorted { $0.updated > $1.updated }
            loadError = nil
            postScores(after: nil)
        } catch {
            loadError = Self.friendly(error, doing: "load your challenges")
        }
    }

    /// Builds the lobby row, and tidies up matches that need it: counts
    /// finished ones in the head-to-head record, and moves on a match that
    /// is stuck with us (the friend declined or ran out of time, or our
    /// last send didn't get through).
    private func item(for match: GKTurnBasedMatch, data: ChallengeData?) async -> ChallengeItem? {
        let me = localPlayerID
        let mine = match.participants.first { $0.player?.gamePlayerID == me }
        let seats = self.seats(of: match, data: data)
        let others = seats.filter { !$0.isMe }
        let isGroup = match.participants.count > 2
        // Head-to-head: the other player. Group: nobody in particular.
        let opponent = isGroup ? nil : match.participants.first { $0.player?.gamePlayerID != me }
        let name = isGroup ? ChallengeItem.groupName(others.map(\.name))
            : opponent?.player?.displayName ?? "Someone new"
        for p in match.participants { if let player = p.player, player.gamePlayerID != me { knownPlayers[player.gamePlayerID] = player } }
        let updated = match.participants.compactMap(\.lastTurnDate).max() ?? match.creationDate
        var item = ChallengeItem(id: match.matchID, opponentID: opponent?.player?.gamePlayerID,
                                 opponentName: name, status: .theirTurn,
                                 myPoints: data?.turn(for: me)?.points,
                                 theirPoints: others.compactMap(\.points).max(),
                                 updated: updated, setup: data?.setup, seats: seats)
        if let data, !data.isSupported {
            item.status = .needsUpdate
            return item
        }
        let myTurn = match.currentParticipant?.player?.gamePlayerID == me
        switch match.status {
        case .ended:
            let outcome = mine.flatMap { Self.outcome(from: $0.matchOutcome) }
            item.status = .finished(outcome)
            if let data {
                let ids = seats.map(\.id)
                item.place = data.standings(among: ids).first { $0.playerID == me }?.place
                archiveMatch(match.matchID, data: data, seats: seats, at: updated)
            }
            // Head-to-head records only count one-on-one matches.
            if !isGroup, let outcome, let opponentID = item.opponentID, let data,
               data.isContested(between: me, and: opponentID) {
                // Both dedupe by match ID, so seeing the match again is a no-op.
                store.recordMatch(outcome, against: opponentID, name: name,
                                  matchID: match.matchID, at: updated)
                addToHistory(ChallengeGame(matchID: match.matchID, data: data, me: me,
                                           opponentID: opponentID, opponentName: name,
                                           outcome: outcome, playedAt: updated))
            }
        case _ where mine?.status == .invited && data?.hasPlayed(me) == true:
            // Our score carried over from the head-to-head this group grew
            // out of: nothing to play, just waiting on the others.
            item.status = .theirTurn
        case _ where mine?.status == .invited:
            item.status = .invited
        case _ where myTurn:
            if let data, data.hasPlayed(me), !busy.contains(match.matchID) {
                // We already played but the turn is still ours: pass it on
                // again, or close the match if nobody is left to play.
                busy.insert(match.matchID)
                defer { busy.remove(match.matchID) }
                if (try? await passOrFinish(match, data: data)) != nil {
                    return await self.item(for: match, data: data)
                }
            }
            item.status = .yourTurn
        case _ where !isGroup && opponent?.player == nil:
            item.status = .findingOpponent
        case _ where !others.isEmpty && others.allSatisfy({ $0.state == .out }):
            item.status = .declined
        default:
            item.status = .theirTurn
        }
        return item
    }

    /// Opens a lobby row: the round if it's our turn, or the result.
    func open(_ item: ChallengeItem) async {
        if isDemo { return openDemo(item) }
        if item.status == .needsUpdate {
            errorMessage = "\(item.opponentName) has a newer Quizio. Update the app from TestFlight or the App Store to play this one."
            return
        }
        do {
            let match = try await GKTurnBasedMatch.load(withID: item.id)
            matches[match.matchID] = match
            try await presentMatch(match)
        } catch {
            errorMessage = Self.friendly(error, doing: "open that challenge")
        }
    }

    /// Shows a match full screen, accepting the invite first if needed.
    /// Never replaces a round that's being played.
    private func presentMatch(_ match: GKTurnBasedMatch) async throws {
        guard activeRound == nil else { return }
        var match = match
        // A match that became a group match opens the group instead.
        if let next = successors[match.matchID] {
            match = try await GKTurnBasedMatch.load(withID: next)
            matches[match.matchID] = match
        }
        let me = localPlayerID
        if match.participants.first(where: { $0.player?.gamePlayerID == me })?.status == .invited {
            match = try await match.acceptInvite()
            matches[match.matchID] = match
        }
        try await show(match)
    }

    private func show(_ match: GKTurnBasedMatch, setup: ChallengeSetup? = nil) async throws {
        let me = localPlayerID
        var data: ChallengeData
        if let existing = await challengeData(of: match, useCache: false) {
            data = existing
        } else if match.currentParticipant?.player?.gamePlayerID == me {
            // A brand-new match we started: deal now and save straight away,
            // so backing out and coming back can't re-roll the questions.
            data = store.newChallenge(setup ?? nextSetup)
            data.setPlayer(localPlayerInfo, for: me)
            try await match.saveCurrentTurn(withMatch: data.encoded())
        } else {
            return
        }
        if !data.isSupported {
            errorMessage = "This challenge needs a newer Quizio. Update the app to play it."
            return
        }
        guard activeRound == nil else { return }
        activeRound = round(for: match, data: data)
    }

    /// The full-screen round for a match.
    func round(for match: GKTurnBasedMatch, data: ChallengeData) -> ChallengeRound {
        let me = localPlayerID
        let seats = self.seats(of: match, data: data)
        let isGroup = match.participants.count > 2
        let opponent = isGroup ? nil : match.participants.first { $0.player?.gamePlayerID != me }
        return ChallengeRound(
            id: match.matchID, data: data,
            opponentID: opponent?.player?.gamePlayerID,
            opponentName: isGroup ? ChallengeItem.groupName(seats.filter { !$0.isMe }.map(\.name))
                : opponent?.player?.displayName ?? "your opponent",
            playerIDs: match.participants.filter { $0.matchOutcome != .quit }.compactMap { $0.player?.gamePlayerID },
            seats: seats,
            isMyTurn: match.status != .ended && match.currentParticipant?.player?.gamePlayerID == me)
    }

    // MARK: Playing

    /// Saves our turn and passes the match on, or ends it if we were last.
    /// Safe to retry: if an earlier attempt already got through, this just
    /// returns what's on Game Center. Returns the updated data so the result
    /// screen can show both scores.
    func submit(_ session: GameSession, in round: ChallengeRound) async throws -> ChallengeData {
        let turn = pending[round.id] ?? ChallengeTurn(playerID: localPlayerID, session: session)
        if isDemo { return submitDemo(turn, in: round) }
        setPending(turn, for: round.id)
        let data = try await send(turn, matchID: round.id, fallback: round.data)
        await refresh()
        return data
    }

    private func send(_ turn: ChallengeTurn, matchID: String, fallback: ChallengeData?) async throws -> ChallengeData {
        busy.insert(matchID)
        defer { busy.remove(matchID) }
        // Always work on a fresh copy: a match object from before the round
        // can be out of date, and Game Center rejects turns made on it.
        let match = try await GKTurnBasedMatch.load(withID: matchID)
        matches[match.matchID] = match
        guard var data = await challengeData(of: match, useCache: false) ?? fallback else {
            throw ChallengeError.matchMissing
        }
        let me = localPlayerID
        let stillOurs = match.status != .ended && match.currentParticipant?.player?.gamePlayerID == me
        if data.hasPlayed(me) && !stillOurs {
            // An earlier send went through; nothing more to do.
            setPending(nil, for: matchID)
            return data
        }
        guard stillOurs else {
            setPending(nil, for: matchID)
            throw ChallengeError.notYourTurn
        }
        data.record(turn)
        data.setPlayer(localPlayerInfo, for: me)
        // Store the score on Game Center first, so a dropped connection
        // while passing the turn can't lose it. The lobby finishes the
        // hand-off next time it loads.
        try await match.saveCurrentTurn(withMatch: data.encoded())
        setPending(nil, for: matchID)
        cache[match.matchID] = nil
        try? await passOrFinish(match, data: data, message: "\(localPlayerName) scored \(turn.points.formatted()). Your turn!")
        return data
    }

    /// Whether this match has a played round waiting to send.
    func hasPendingTurn(_ matchID: String) -> Bool { pending[matchID] != nil }

    private func setPending(_ turn: ChallengeTurn?, for matchID: String) {
        pending[matchID] = turn
        defaults.setEncoded(pending, forKey: Self.pendingKey, using: .challenge)
    }

    /// Sends rounds that were played offline. Runs before each lobby load.
    private func sendPendingTurns() async {
        for (matchID, turn) in pending where !busy.contains(matchID) {
            _ = try? await send(turn, matchID: matchID, fallback: nil)
        }
    }

    /// Passes the turn to whoever still has to play, or ends the match when
    /// nobody does. We go last in the turn order so that, if the friend
    /// doesn't play in time, Game Center hands the match back to us and we
    /// can close it, instead of it hanging forever.
    private func passOrFinish(_ match: GKTurnBasedMatch, data: ChallengeData, message: String? = nil) async throws {
        let me = localPlayerID
        let waiting = match.participants.filter { p in
            guard p.player?.gamePlayerID != me, p.matchOutcome == .none,
                  p.status != .declined, p.status != .done else { return false }
            return p.player.map { !data.hasPlayed($0.gamePlayerID) } ?? true
        }
        if waiting.isEmpty {
            try await finish(match, data: data)
        } else {
            let mine = match.participants.filter { $0.player?.gamePlayerID == me }
            match.message = message ?? "\(localPlayerName) is waiting on you. Your turn!"
            try await match.endTurn(withNextParticipants: waiting + mine,
                                    turnTimeout: Self.turnTimeout,
                                    match: data.encoded())
        }
        cache[match.matchID] = nil
    }

    /// Sets everyone's outcome from the scores and ends the match. Anyone
    /// who never played (declined, quit, timed out) doesn't win.
    private func finish(_ match: GKTurnBasedMatch, data: ChallengeData) async throws {
        let ids = match.participants.compactMap { $0.player?.gamePlayerID }
        let results = data.finalResults(for: ids)
        for p in match.participants where p.matchOutcome == .none {
            guard let id = p.player?.gamePlayerID else { p.matchOutcome = .quit; continue }
            switch results[id] ?? .didNotPlay {
            case .won: p.matchOutcome = .won
            case .lost: p.matchOutcome = .lost
            case .tied: p.matchOutcome = .tied
            case .didNotPlay: p.matchOutcome = p.status == .declined ? .quit : .timeExpired
            }
        }
        match.message = match.participants.count > 2
            ? "Group match finished. See the standings!"
            : "Challenge finished. See who won!"
        try await match.endMatchInTurn(withMatch: data.encoded())
    }

    /// Starts a new match with the same friend, on the same rules, and opens it.
    func rematch(_ matchID: String) async {
        if isDemo { return rematchDemo(matchID) }
        do {
            let old = try await GKTurnBasedMatch.load(withID: matchID)
            // Same rules as last time.
            let setup = await challengeData(of: old)?.setup
            let next = try await old.rematch()
            matches[next.matchID] = next
            try await show(next, setup: setup)
            await refresh()
        } catch {
            errorMessage = Self.friendly(error, doing: "start a rematch")
        }
    }

    /// Turns down an invite, or gives up a match in progress (counts as a
    /// loss once it ends), or clears a finished one from the list.
    func remove(_ item: ChallengeItem) async {
        if isDemo {
            challenges.removeAll { $0.id == item.id }
            return
        }
        busy.insert(item.id)
        defer { busy.remove(item.id) }
        do {
            let match = try await GKTurnBasedMatch.load(withID: item.id)
            let me = localPlayerID
            let myTurn = match.currentParticipant?.player?.gamePlayerID == me
            if match.status != .ended {
                if match.participants.first(where: { $0.player?.gamePlayerID == me })?.status == .invited {
                    try await match.declineInvite()
                } else if myTurn {
                    let data = await challengeData(of: match, useCache: false)
                    let others = match.participants.filter {
                        $0.player?.gamePlayerID != me && $0.matchOutcome == .none
                    }
                    if let data, data.hasPlayed(me) || others.isEmpty {
                        // Already played (or nobody left): just close it out.
                        try await finish(match, data: data)
                    } else {
                        try await match.participantQuitInTurn(
                            with: .quit, nextParticipants: others, turnTimeout: Self.turnTimeout,
                            match: match.matchData ?? Data())
                    }
                } else {
                    try await match.participantQuitOutOfTurn(with: .quit)
                }
            }
            if item.isFinished || item.status == .declined || match.status == .ended {
                try? await match.remove()
            }
            challenges.removeAll { $0.id == item.id && (item.isFinished || item.status == .declined) }
            cache[item.id] = nil
            await refresh()
        } catch {
            errorMessage = Self.friendly(error, doing: "remove that challenge")
        }
    }

    // MARK: New challenge

    /// Shows Game Center's friend picker. Once a friend is picked the new
    /// match arrives as a turn event and opens straight into the intro.
    func newChallenge(with players: [GKPlayer] = []) {
        if isDemo { return newDemoChallenge() }
        let request = GKMatchRequest()
        request.minPlayers = 2
        // Pick one friend for a head-to-head, or several for a group match.
        request.maxPlayers = ChallengeData.maxPlayers
        request.defaultNumberOfPlayers = max(2, players.count + 1)
        request.inviteMessage = nextSetup.isCustom
            ? "Think you know more than me? Play my Quizio round: \(nextSetup.summary)."
            : "Think you know more than me? Play my Quizio round."
        if !players.isEmpty { request.recipients = players }
        let picker = GKTurnBasedMatchmakerViewController(matchRequest: request)
        picker.turnBasedMatchmakerDelegate = self
        // Our lobby lists matches; the picker only starts new ones.
        picker.showExistingMatches = false
        present(picker)
    }

    // MARK: Helpers

    /// nil for a match nobody has dealt yet (or data we can't read). A
    /// finished match never changes and a waiting one only changes when
    /// someone takes a turn, so the lobby reuses what it loaded before
    /// unless the match has moved on.
    private func challengeData(of match: GKTurnBasedMatch, useCache: Bool = true) async -> ChallengeData? {
        let stamp = Self.stamp(of: match)
        if useCache, let hit = cache[match.matchID], hit.stamp == stamp { return hit.data }
        guard let raw = try? await match.loadMatchData() else { return nil }
        let data = raw.isEmpty ? nil : try? ChallengeData(matchData: raw)
        cache[match.matchID] = (stamp, data)
        return data
    }

    private static func stamp(of match: GKTurnBasedMatch) -> String {
        let last = match.participants.compactMap(\.lastTurnDate).max()?.timeIntervalSince1970 ?? 0
        return "\(match.status.rawValue)|\(match.currentParticipant?.player?.gamePlayerID ?? "-")|\(last)"
    }

    /// Plain-language error text for the common Game Center failures.
    static func friendly(_ error: any Error, doing action: String) -> String {
        if let challenge = error as? ChallengeError { return challenge.errorDescription ?? "" }
        let code = (error as? GKError)?.code
        switch code {
        case .notAuthenticated:
            return "Couldn't \(action). Sign in to Game Center in Settings and try again."
        case .communicationsFailure, .connectionTimeout, .unknown:
            return "Couldn't \(action). Check your connection and try again."
        case .invalidParameter, .turnBasedInvalidTurn, .turnBasedInvalidState, .turnBasedInvalidParticipant:
            return "Couldn't \(action). It changed on another device. Pull down to refresh."
        case .gameUnrecognized, .notSupported:
            return "Game Center isn't set up for Quizio yet. Please try again later."
        default:
            if let url = error as? URLError, url.code == .notConnectedToInternet {
                return "Couldn't \(action). You're offline."
            }
            return "Couldn't \(action). \(error.localizedDescription)"
        }
    }

    /// Two days per turn: long enough to play at your own pace, short
    /// enough that a forgotten challenge comes back and gets closed out.
    private static let turnTimeout: TimeInterval = 2 * 24 * 60 * 60

    private func addToHistory(_ game: ChallengeGame?) {
        guard let game, history.add(game) else { return }
        defaults.setEncoded(history, forKey: Self.historyKey)
    }

    private static func outcome(from gk: GKTurnBasedMatch.Outcome) -> ChallengeOutcome? {
        switch gk {
        case .won: .won
        case .lost, .quit, .timeExpired: .lost
        case .tied: .tied
        default: nil
        }
    }

    /// The view controller on top of the key window, to present Game
    /// Center's own screens over whatever is showing.
    private var topViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    private func present(_ controller: UIViewController) {
        topViewController?.present(controller, animated: true)
    }

    /// Closes Game Center's friend picker if it's up, then runs `action`.
    private func dismissPresented(then action: @escaping @MainActor () -> Void) {
        if let picker = topViewController as? GKTurnBasedMatchmakerViewController {
            picker.dismiss(animated: true) { action() }
        } else {
            action()
        }
    }

    /// Debug builds only: `-demoFriends` fills the lobby with sample
    /// challenges so the screens can be tried without two Game Center accounts.
    nonisolated static var demoRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-demoFriends")
        #else
        false
        #endif
    }
}

// MARK: Group matches, seats and the archive

extension GameCenter {
    /// Your card and app build, written into every match you deal or play.
    var localPlayerInfo: ChallengePlayer {
        ChallengePlayer(card: SharedCard(store: store, fallbackName: localPlayerName),
                        build: AppBuild.number, version: AppBuild.version)
    }

    /// Everyone in a match, you first, then in turn order.
    func seats(of match: GKTurnBasedMatch, data: ChallengeData?) -> [MatchSeat] {
        let me = localPlayerID
        let current = match.currentParticipant?.player?.gamePlayerID
        var seats: [MatchSeat] = []
        for p in match.participants {
            guard let player = p.player else { continue }
            let id = player.gamePlayerID
            let isMe = id == me
            let state: MatchSeat.State
            if data?.hasPlayed(id) == true {
                state = .played
            } else if p.status == .declined || p.matchOutcome == .quit || p.matchOutcome == .timeExpired
                        || (match.status == .ended) {
                state = .out
            } else if id == current {
                state = .up
            } else {
                state = .waiting
            }
            let info = data?.player(id)
            seats.append(MatchSeat(id: id, name: isMe ? "You" : player.displayName, isMe: isMe, state: state,
                                   points: data?.turn(for: id)?.points,
                                   card: info?.card ?? (isMe ? localPlayerInfo.card : nil),
                                   build: info?.build))
        }
        return seats.filter(\.isMe) + seats.filter { !$0.isMe }
    }

    /// Starts a group match with these friends (one friend makes a
    /// head-to-head) and opens it to deal and play first.
    func startMatch(with friendIDs: [String]) async {
        if isDemo { return newDemoChallenge(group: friendIDs) }
        let players = friendIDs.compactMap { knownPlayers[$0] }
        guard !players.isEmpty else { return newChallenge() }
        do {
            let request = GKMatchRequest()
            request.minPlayers = players.count + 1
            request.maxPlayers = players.count + 1
            request.recipients = players
            request.inviteMessage = players.count > 1
                ? "Group match! Play my Quizio round against \(players.count) friends."
                : "Think you know more than me? Play my Quizio round."
            let match = try await GKTurnBasedMatch.find(for: request)
            matches[match.matchID] = match
            try await show(match)
            await refresh()
        } catch {
            errorMessage = Self.friendly(error, doing: "start that match")
        }
    }

    /// Brings more friends into a match by moving it to a new, bigger group
    /// match with the same questions. Everyone's score so far carries over.
    /// The old match is closed without counting, by whoever holds its turn.
    func invite(_ friendIDs: [String], into matchID: String) async {
        if isDemo { return inviteDemo(friendIDs, into: matchID) }
        let me = localPlayerID
        do {
            let old = try await GKTurnBasedMatch.load(withID: matchID)
            guard old.status != .ended, let data = await challengeData(of: old, useCache: false) else {
                throw ChallengeError.matchMissing
            }
            guard data.allowsInvites else { throw ChallengeError.invitesOff }
            let current = old.currentParticipant?.player?.gamePlayerID
            let stillIn = old.participants.filter { p in
                p.player != nil && p.player?.gamePlayerID != me
                    && p.status != .declined && p.matchOutcome == .none
            }
            // Whoever hasn't played goes first, starting with whoever holds
            // the old match's turn, so they see the group before playing the
            // old one. Players who already played never need a turn.
            let unplayedAll = stillIn.filter { !data.hasPlayed($0.player!.gamePlayerID) }
            let unplayed = unplayedAll.filter { $0.player?.gamePlayerID == current }
                + unplayedAll.filter { $0.player?.gamePlayerID != current }
            let played = stillIn.filter { data.hasPlayed($0.player!.gamePlayerID) }
            let existing = Set(stillIn.compactMap { $0.player?.gamePlayerID })
            let added = friendIDs.filter { !existing.contains($0) && $0 != me }.compactMap { knownPlayers[$0] }
            guard !added.isEmpty else { return }
            let recipients = unplayed.compactMap(\.player) + added + played.compactMap(\.player)
            guard recipients.count + 1 <= ChallengeData.maxPlayers else { throw ChallengeError.groupFull }

            let request = GKMatchRequest()
            request.minPlayers = recipients.count + 1
            request.maxPlayers = recipients.count + 1
            request.recipients = recipients
            request.inviteMessage = "\(localPlayerName) made this a group match. Join in!"
            let group = try await GKTurnBasedMatch.find(for: request)
            matches[group.matchID] = group
            var copy = data.groupCopy(from: old.matchID)
            copy.setPlayer(localPlayerInfo, for: me)
            try await group.saveCurrentTurn(withMatch: copy.encoded())
            cache[group.matchID] = nil
            successors[old.matchID] = group.matchID

            // Close the old match now if we can; otherwise the player whose
            // turn it is closes it when they see the group.
            if current == me {
                await closeSuperseded(old, data: data, movedTo: group.matchID)
            }
            if copy.hasPlayed(me) {
                busy.insert(group.matchID)
                defer { busy.remove(group.matchID) }
                try await passOrFinish(group, data: copy,
                                       message: "\(localPlayerName) made this a group match. Your turn!")
                activeRound = nil
            } else {
                activeRound = nil
                try await show(group)
            }
            await refresh()
        } catch {
            errorMessage = Self.friendly(error, doing: "invite them")
        }
    }

    /// Ends a match that moved into a group match, without anyone winning
    /// or losing. Only works on our turn; otherwise it waits for whoever
    /// holds the turn. Finished ones are just cleared from Game Center.
    func closeSuperseded(_ match: GKTurnBasedMatch, data: ChallengeData?, movedTo next: String) async {
        let me = localPlayerID
        if match.status == .ended {
            try? await match.remove()
            return
        }
        guard match.currentParticipant?.player?.gamePlayerID == me,
              !busy.contains(match.matchID), var data else { return }
        busy.insert(match.matchID)
        defer { busy.remove(match.matchID) }
        data.movedTo = next
        for p in match.participants where p.matchOutcome == .none { p.matchOutcome = .tied }
        match.message = "This match moved into a group match."
        if (try? await match.endMatchInTurn(withMatch: data.encoded())) != nil {
            cache[match.matchID] = nil
            try? await match.remove()
        }
    }

    /// Keeps a finished match on this phone for its breakdown and replay.
    func archiveMatch(_ matchID: String, data: ChallengeData, seats: [MatchSeat], at date: Date) {
        guard data.movedTo == nil else { return }
        var names: [String: String] = [:]
        for seat in seats { names[seat.id] = seat.name }
        let entry = ArchivedMatch(matchID: matchID, data: data, playerIDs: seats.map(\.id),
                                  names: names, finishedAt: date)
        // Keep the first finish time, so re-reading the match doesn't reorder it.
        if let existing = archive.match(matchID), existing.data == data { return }
        if archive.add(entry) { MatchArchiveFile.save(archive) }
    }

    /// Opens the breakdown and replay of a finished match.
    func review(_ matchID: String) {
        reviewing = archive.match(matchID)
    }

    /// Friends who could join a match: Game Center friends and anyone
    /// you've played, minus who's already in.
    func invitable(excluding ids: Set<String>) -> [Friend] {
        friendRows.filter { !ids.contains($0.id) && (knownPlayers[$0.id] != nil || isDemo) }
    }
}

/// Where the match archive lives: a JSON file in Application Support (too
/// big for UserDefaults once it holds dozens of matches).
enum MatchArchiveFile {
    private static var url: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            .appendingPathComponent("match-archive.v1.json")
    }

    static func load() -> MatchArchive {
        guard let url, let data = try? Data(contentsOf: url),
              let archive = try? JSONDecoder.challenge.decode(MatchArchive.self, from: data) else { return MatchArchive() }
        return archive
    }

    static func save(_ archive: MatchArchive) {
        guard let url, let data = try? JSONEncoder.challenge.encode(archive) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// The part of the old standalone rivalry file still worth reading.
private struct LegacyRivalries: Decodable {
    var countedMatchIDs: Set<String> = []
}

enum ChallengeError: LocalizedError {
    case matchMissing
    case notYourTurn
    case invitesOff
    case groupFull
    var errorDescription: String? {
        switch self {
        case .matchMissing: "That challenge isn't available any more."
        case .invitesOff: "This match was set up without invites, so nobody else can join."
        case .groupFull: "A match can have up to \(ChallengeData.maxPlayers) players."
        case .notYourTurn: "This challenge moved on without you, so your score couldn't be sent. Pull down in Friends to see where it stands."
        }
    }
}

// MARK: Game Center events

extension GameCenter: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        nonisolated(unsafe) let match = match
        Task { @MainActor in
            // Keep the copy Game Center just gave us: a brand-new match may
            // not show up in loadMatches for a moment.
            self.matches[match.matchID] = match
            self.cache[match.matchID] = nil
            // didBecomeActive: the player tapped a notification, or just
            // picked a friend in the matchmaker. Take them straight there.
            if didBecomeActive {
                self.dismissPresented {
                    Task {
                        do { try await self.presentMatch(match) } catch {
                            self.errorMessage = Self.friendly(error, doing: "open that challenge")
                        }
                    }
                }
            }
            await self.refresh()
        }
    }

    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        let matchID = match.matchID
        Task { @MainActor in
            self.cache[matchID] = nil
            await self.refresh()
        }
    }

    /// Quit from Game Center's own UI while it's our turn.
    nonisolated func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        let matchID = match.matchID
        Task { @MainActor in
            await self.refresh()
            if let item = self.challenges.first(where: { $0.id == matchID }) {
                await self.remove(item)
            }
        }
    }

    /// "Challenge" picked for this game from the Games app or a contact.
    nonisolated func player(_ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer]) {
        nonisolated(unsafe) let players = playersToInvite
        Task { @MainActor in self.newChallenge(with: players) }
    }
}

extension GameCenter: GKTurnBasedMatchmakerViewControllerDelegate {
    nonisolated func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        Task { @MainActor in viewController.dismiss(animated: true) }
    }

    nonisolated func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController,
                                                       didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            viewController.dismiss(animated: true)
            self.errorMessage = "Couldn't start a challenge. \(message)"
        }
    }
}

// MARK: Demo data (debug builds)

private extension GameCenter {
    func loadDemo() {
        auth = .signedIn
        let now = Date()
        challenges = [
            ChallengeItem(id: "d1", opponentID: "maya", opponentName: "Maya", status: .yourTurn,
                          myPoints: nil, theirPoints: 1_240, updated: now.addingTimeInterval(-600),
                          seats: demoSeats([("maya", "Maya")])),
            ChallengeItem(id: "d6", opponentID: nil, opponentName: "Maya, Sam & Priya", status: .yourTurn,
                          myPoints: nil, theirPoints: 1_310, updated: now.addingTimeInterval(-900),
                          seats: demoSeats([("maya", "Maya"), ("sam", "Sam"), ("priya", "Priya")])),
            ChallengeItem(id: "d2", opponentID: "sam", opponentName: "Sam", status: .invited,
                          myPoints: nil, theirPoints: 980, updated: now.addingTimeInterval(-3_600),
                          seats: demoSeats([("sam", "Sam")])),
            ChallengeItem(id: "d3", opponentID: "jordan", opponentName: "Jordan", status: .theirTurn,
                          myPoints: 1_105, theirPoints: nil, updated: now.addingTimeInterval(-7_200),
                          seats: demoSeats([("jordan", "Jordan")]).map { var s = $0; if !s.isMe { s.state = .up }; return s }),
            ChallengeItem(id: "d7", opponentID: nil, opponentName: "Jordan, Priya, Sam & Maya", status: .finished(.won),
                          myPoints: 1_420, theirPoints: 1_300, updated: now.addingTimeInterval(-40_000),
                          seats: demoSeats([("jordan", "Jordan"), ("priya", "Priya"), ("sam", "Sam"), ("maya", "Maya")]),
                          place: 1),
            ChallengeItem(id: "d4", opponentID: "maya", opponentName: "Maya", status: .finished(.won),
                          myPoints: 1_360, theirPoints: 1_020, updated: now.addingTimeInterval(-86_400),
                          seats: demoSeats([("maya", "Maya")])),
            ChallengeItem(id: "d5", opponentID: "sam", opponentName: "Sam", status: .finished(.lost),
                          myPoints: 870, theirPoints: 1_190, updated: now.addingTimeInterval(-172_800),
                          seats: demoSeats([("sam", "Sam")])),
        ]
        var book = RivalryBook()
        for (i, (id, name, outcome)) in [("maya", "Maya", ChallengeOutcome.won), ("maya", "Maya", .won),
                                         ("maya", "Maya", .lost), ("sam", "Sam", .lost),
                                         ("jordan", "Jordan", .tied)].enumerated() {
            book.add(outcome, against: id, name: name, at: now.addingTimeInterval(Double(-i) * 3_600))
        }
        demoRivals = book
        var log = ChallengeHistory()
        let demoGames: [(String, String, ChallengeOutcome, Int, Int, ChallengeSetup)] = [
            ("maya", "Maya", .won, 1_360, 1_020, .standard),
            ("maya", "Maya", .won, 1_180, 1_150, ChallengeSetup(difficulty: .hard)),
            ("maya", "Maya", .lost, 940, 1_210, ChallengeSetup(mode: .speed)),
            ("sam", "Sam", .lost, 870, 1_190, ChallengeSetup(categories: ["Science"], length: 15)),
            ("jordan", "Jordan", .tied, 1_000, 1_000, ChallengeSetup(isTimed: false)),
        ]
        for (i, g) in demoGames.enumerated() {
            log.add(ChallengeGame(matchID: "demo\(i)", opponentID: g.0, opponentName: g.1, outcome: g.2,
                                  myPoints: g.3, theirPoints: g.4, myCorrect: g.3 / 140, theirCorrect: g.4 / 140,
                                  questionCount: g.5.questionCount, setup: g.5,
                                  playedAt: now.addingTimeInterval(Double(-i) * 3_600 - 86_400)))
        }
        history = log
        loadDemoFriends()
    }

    func demoRound(for item: ChallengeItem, data: ChallengeData) -> ChallengeRound {
        let seats = item.seats.map { seat in
            var s = seat
            s.points = data.turn(for: seat.id)?.points
            s.card = data.player(seat.id)?.card ?? seat.card
            return s
        }
        return ChallengeRound(id: item.id, data: data, opponentID: item.opponentID,
                              opponentName: item.opponentName, playerIDs: seats.map(\.id),
                              seats: seats, isMyTurn: !data.hasPlayed("me"))
    }

    /// Sample seats: you plus these friends, with made-up cards.
    func demoSeats(_ others: [(String, String)]) -> [MatchSeat] {
        let looks: [[CosmeticSlot: String]] = [
            [.avatar: "avatar.planet", .border: "border.spark", .cardBackground: "bg.sky"],
            [.avatar: "avatar.cat", .border: "border.rainbow", .cardBackground: "bg.sunset"],
            [.avatar: "avatar.bird", .border: "border.ink", .cardBackground: "bg.mint"],
            [.avatar: "avatar.bolt", .border: "border.coral", .cardBackground: "bg.stripes"],
            [.avatar: "avatar.star", .border: "border.ink", .cardBackground: "bg.paper"],
        ]
        var seats = [MatchSeat(id: "me", name: "You", isMe: true, state: .waiting,
                               card: localPlayerInfo.card, build: AppBuild.number)]
        for (i, (id, name)) in others.enumerated() {
            var items: [String: String] = [:]
            for (slot, item) in looks[i % looks.count] { items[slot.rawValue] = item }
            seats.append(MatchSeat(id: id, name: name, isMe: false, state: .played,
                                   card: SharedCard(name: name, title: "Quiz Whiz", statLabel: "Best streak",
                                                    statValue: "\(8 + i * 3)", items: items),
                                   build: AppBuild.number + (id == "sam" ? 1 : 0)))
        }
        return seats
    }

    /// A made-up turn with picks, so breakdowns and replays have something to show.
    func demoTurn(_ id: String, data: ChallengeData, skill: Int, points: Int? = nil) -> ChallengeTurn {
        var picks: [ChallengePick] = []
        var total = 0
        for (i, q) in data.questions.prefix(10).enumerated() {
            let hash = abs((id + q.prompt).hashValue)
            let correct = (hash + i) % 10 < skill
            let wrong = q.choices.indices.first { $0 != q.correctIndex } ?? 0
            let seconds = 2 + Double(hash % 120) / 10
            let p = correct ? 100 + Int(GameRules.questionTime - seconds) * 5 : 0
            total += p
            picks.append(ChallengePick(questionID: q.id, choice: correct ? q.correctIndex : wrong,
                                       seconds: seconds, correct: correct, points: p))
        }
        return ChallengeTurn(playerID: id, points: points ?? total, correctCount: picks.filter(\.correct).count,
                             bestStreak: 3, answers: picks.map(\.correct), picks: picks)
    }

    func openDemo(_ item: ChallengeItem) {
        var data = store.newChallenge()
        for (i, seat) in item.seats.enumerated() {
            if let card = seat.card { data.setPlayer(ChallengePlayer(card: card, build: seat.build ?? 0), for: seat.id) }
            let points = seat.isMe ? item.myPoints : seat.points
            if seat.state == .played || (seat.isMe && points != nil) {
                data.record(demoTurn(seat.id, data: data, skill: seat.isMe ? 7 : 5 + i, points: points))
            }
        }
        if item.isFinished {
            let seats = item.seats
            archiveMatch(item.id, data: data, seats: seats, at: item.updated)
            reviewing = archive.match(item.id)
            return
        }
        activeRound = demoRound(for: item, data: data)
    }

    func inviteDemo(_ friendIDs: [String], into matchID: String) {
        guard let i = challenges.firstIndex(where: { $0.id == matchID }) else { return }
        let names = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0.name) })
        let extra = demoSeats(friendIDs.map { ($0, names[$0] ?? "Friend") }).dropFirst().map { seat in
            var s = seat
            s.state = .waiting
            return s
        }
        challenges[i].seats += extra
        activeRound?.seats += extra
    }

    func submitDemo(_ turn: ChallengeTurn, in round: ChallengeRound) -> ChallengeData {
        var data = round.data
        data.record(turn)
        if let i = challenges.firstIndex(where: { $0.id == round.id }) {
            challenges[i].myPoints = turn.points
            let outcome = data.outcome(for: "me", among: round.playerIDs)
            challenges[i].status = outcome.map { .finished($0) } ?? .theirTurn
            challenges[i].updated = Date()
        }
        return data
    }

    func rematchDemo(_ matchID: String) {
        guard let old = challenges.first(where: { $0.id == matchID }) else { return }
        let item = ChallengeItem(id: UUID().uuidString, opponentID: old.opponentID,
                                 opponentName: old.opponentName, status: .yourTurn,
                                 myPoints: nil, theirPoints: nil, updated: Date(),
                                 seats: old.seats.map { var s = $0; s.state = s.isMe ? .up : .waiting; s.points = nil; return s })
        challenges.insert(item, at: 0)
        openDemo(item)
    }

    func newDemoChallenge(group: [String] = []) {
        let names = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0.name) })
        let people = group.isEmpty ? [("riley", "Riley")] : group.map { ($0, names[$0] ?? "Friend") }
        let seats = demoSeats(people).map { seat in
            var s = seat
            s.state = s.isMe ? .up : .waiting
            return s
        }
        let item = ChallengeItem(id: UUID().uuidString, opponentID: people.count == 1 ? people[0].0 : nil,
                                 opponentName: ChallengeItem.groupName(people.map(\.1)),
                                 status: .yourTurn, myPoints: nil, theirPoints: nil, updated: Date(), seats: seats)
        challenges.insert(item, at: 0)
        openDemo(item)
    }
}
