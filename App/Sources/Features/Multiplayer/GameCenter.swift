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
    let opponentID: String?
    let opponentName: String
    var status: Status
    var myPoints: Int?
    var theirPoints: Int?
    var updated: Date

    var isFinished: Bool { if case .finished = status { true } else { false } }
}

/// A challenge round to show full screen: the intro, the round itself, or
/// the result of a finished match.
struct ChallengeRound: Identifiable {
    let id: String
    var data: ChallengeData
    let opponentID: String?
    let opponentName: String
    /// Game Center IDs of everyone still in the match.
    let playerIDs: [String]
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
    private(set) var rivalries: ChallengeRivalryBook
    private(set) var isLoading = false
    /// Drives the full-screen challenge cover.
    var activeRound: ChallengeRound?
    var errorMessage: String?
    /// Why the lobby couldn't load, shown inline instead of an alert so
    /// being offline doesn't pop up a dialog every time.
    private(set) var loadError: String?

    @ObservationIgnored private let store: PlayerStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var matches: [String: GKTurnBasedMatch] = [:]
    @ObservationIgnored private var signInController: UIViewController?
    @ObservationIgnored private var listening = false
    @ObservationIgnored private var queuedRefresh: Task<Void, Never>?
    @ObservationIgnored private var latestRefresh: Task<Void, Never>?
    /// Matches we're sending a turn for, so a lobby refresh leaves them alone.
    @ObservationIgnored private var busy: Set<String> = []
    @ObservationIgnored private var cache: [String: (stamp: String, data: ChallengeData?)] = [:]
    @ObservationIgnored let isDemo: Bool
    private static let rivalriesKey = "rivalries.v1"
    private static let pendingKey = "challenge.pendingTurns.v1"
    /// Turns played but not yet sent, by match ID. Kept on the phone so a
    /// dropped connection never loses a score or lets a round be replayed.
    @ObservationIgnored private var pending: [String: ChallengeTurn] = [:]

    init(store: PlayerStore, defaults: UserDefaults = .standard, demo: Bool = GameCenter.demoRequested) {
        self.store = store
        self.defaults = defaults
        self.isDemo = demo
        if let data = defaults.data(forKey: Self.rivalriesKey),
           let saved = try? JSONDecoder().decode(ChallengeRivalryBook.self, from: data) {
            rivalries = saved
        } else {
            rivalries = ChallengeRivalryBook()
        }
        if let data = defaults.data(forKey: Self.pendingKey),
           let saved = try? JSONDecoder.challenge.decode([String: ChallengeTurn].self, from: data) {
            pending = saved
        }
        super.init()
        if demo { loadDemo() }
    }

    /// Challenges waiting on us, for the Friends tab badge.
    var yourTurnCount: Int { challenges.filter { $0.status == .yourTurn || $0.status == .invited }.count }

    var localPlayerID: String { isDemo ? "me" : GKLocalPlayer.local.gamePlayerID }
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
            for match in loaded {
                byID[match.matchID] = match
                let data = await challengeData(of: match)
                if let item = await item(for: match, data: data) { items.append(item) }
            }
            matches = byID
            challenges = items.sorted { $0.updated > $1.updated }
            loadError = nil
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
        let opponent = match.participants.first { $0.player?.gamePlayerID != me }
        let name = opponent?.player?.displayName ?? "Someone new"
        let updated = match.participants.compactMap(\.lastTurnDate).max() ?? match.creationDate
        var item = ChallengeItem(id: match.matchID, opponentID: opponent?.player?.gamePlayerID,
                                 opponentName: name, status: .theirTurn,
                                 myPoints: data?.turn(for: me)?.points,
                                 theirPoints: opponent?.player.flatMap { data?.turn(for: $0.gamePlayerID)?.points },
                                 updated: updated)
        if let data, !data.isSupported {
            item.status = .needsUpdate
            return item
        }
        let myTurn = match.currentParticipant?.player?.gamePlayerID == me
        switch match.status {
        case .ended:
            let outcome = mine.flatMap { Self.outcome(from: $0.matchOutcome) }
            item.status = .finished(outcome)
            if let outcome, let opponentID = item.opponentID,
               data?.isContested(between: me, and: opponentID) ?? false {
                addToRivalries(outcome, matchID: match.matchID, opponentID: opponentID,
                               name: name, playedAt: updated)
            }
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
        case _ where opponent?.player == nil:
            item.status = .findingOpponent
        case _ where opponent?.status == .declined:
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
        let me = localPlayerID
        if match.participants.first(where: { $0.player?.gamePlayerID == me })?.status == .invited {
            match = try await match.acceptInvite()
            matches[match.matchID] = match
        }
        try await show(match)
    }

    private func show(_ match: GKTurnBasedMatch) async throws {
        let me = localPlayerID
        var data: ChallengeData
        if let existing = await challengeData(of: match, useCache: false) {
            data = existing
        } else if match.currentParticipant?.player?.gamePlayerID == me {
            // A brand-new match we started: deal now and save straight away,
            // so backing out and coming back can't re-roll the questions.
            data = store.newChallenge()
            try await match.saveCurrentTurn(withMatch: data.encoded())
        } else {
            return
        }
        if !data.isSupported {
            errorMessage = "This challenge needs a newer Quizio. Update the app to play it."
            return
        }
        guard activeRound == nil else { return }
        let opponent = match.participants.first { $0.player?.gamePlayerID != me }
        activeRound = ChallengeRound(
            id: match.matchID, data: data,
            opponentID: opponent?.player?.gamePlayerID,
            opponentName: opponent?.player?.displayName ?? "your opponent",
            playerIDs: match.participants.filter { $0.matchOutcome != .quit }.compactMap { $0.player?.gamePlayerID })
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
        if let data = try? JSONEncoder.challenge.encode(pending) {
            defaults.set(data, forKey: Self.pendingKey)
        }
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
        match.message = "Challenge finished. See who won!"
        try await match.endMatchInTurn(withMatch: data.encoded())
    }

    /// Leaves a round partway: whatever was answered counts, the rest are
    /// wrong. Same as playing it out, so quitting never beats losing.
    func forfeit(_ session: GameSession, in round: ChallengeRound) async throws -> ChallengeData {
        try await submit(session, in: round)
    }

    /// Starts a new match with the same friend and opens it.
    func rematch(_ matchID: String) async {
        if isDemo { return rematchDemo(matchID) }
        do {
            let old = try await GKTurnBasedMatch.load(withID: matchID)
            let next = try await old.rematch()
            matches[next.matchID] = next
            try await show(next)
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
        request.maxPlayers = 2
        request.inviteMessage = "Think you know more than me? Play my Quizio round."
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

    private func addToRivalries(_ outcome: ChallengeOutcome, matchID: String,
                                opponentID: String, name: String, playedAt: Date) {
        guard rivalries.add(outcome, matchID: matchID, opponentID: opponentID,
                            opponentName: name, playedAt: playedAt) else { return }
        // Feeds Profile's rivalry stamps (first win, 10 wins vs a friend).
        let result: MatchOutcome = switch outcome {
        case .won: .win
        case .lost: .loss
        case .tied: .tie
        }
        store.recordMatch(result, against: opponentID, name: name)
        if let data = try? JSONEncoder().encode(rivalries) {
            defaults.set(data, forKey: Self.rivalriesKey)
        }
    }

    private static func outcome(from gk: GKTurnBasedMatch.Outcome) -> ChallengeOutcome? {
        switch gk {
        case .won: .won
        case .lost, .quit, .timeExpired: .lost
        case .tied: .tied
        default: nil
        }
    }

    private func present(_ controller: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .sorted(by: { a, _ in a.activationState == .foregroundActive })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(controller, animated: true)
    }

    private func dismissPresented(then action: @escaping @MainActor () -> Void) {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController
        if let presented = root?.presentedViewController, presented is GKTurnBasedMatchmakerViewController {
            presented.dismiss(animated: true) { action() }
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

enum ChallengeError: LocalizedError {
    case matchMissing
    case notYourTurn
    var errorDescription: String? {
        switch self {
        case .matchMissing: "That challenge isn't available any more."
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
                          myPoints: nil, theirPoints: 1_240, updated: now.addingTimeInterval(-600)),
            ChallengeItem(id: "d2", opponentID: "sam", opponentName: "Sam", status: .invited,
                          myPoints: nil, theirPoints: 980, updated: now.addingTimeInterval(-3_600)),
            ChallengeItem(id: "d3", opponentID: "jordan", opponentName: "Jordan", status: .theirTurn,
                          myPoints: 1_105, theirPoints: nil, updated: now.addingTimeInterval(-7_200)),
            ChallengeItem(id: "d4", opponentID: "maya", opponentName: "Maya", status: .finished(.won),
                          myPoints: 1_360, theirPoints: 1_020, updated: now.addingTimeInterval(-86_400)),
            ChallengeItem(id: "d5", opponentID: "sam", opponentName: "Sam", status: .finished(.lost),
                          myPoints: 870, theirPoints: 1_190, updated: now.addingTimeInterval(-172_800)),
        ]
        var book = ChallengeRivalryBook()
        for (i, (id, name, outcome)) in [("maya", "Maya", ChallengeOutcome.won), ("maya", "Maya", .won),
                                         ("maya", "Maya", .lost), ("sam", "Sam", .lost),
                                         ("jordan", "Jordan", .tied)].enumerated() {
            book.add(outcome, matchID: "demo\(i)", opponentID: id, opponentName: name,
                     playedAt: now.addingTimeInterval(Double(-i) * 3_600))
        }
        rivalries = book
    }

    func demoRound(for item: ChallengeItem, data: ChallengeData) -> ChallengeRound {
        ChallengeRound(id: item.id, data: data, opponentID: item.opponentID,
                       opponentName: item.opponentName, playerIDs: ["me", item.opponentID ?? "them"])
    }

    func openDemo(_ item: ChallengeItem) {
        var data = store.newChallenge()
        let them = item.opponentID ?? "them"
        if let points = item.theirPoints {
            data.record(ChallengeTurn(playerID: them, points: points, correctCount: points / 140,
                                      bestStreak: 3, answers: (0..<10).map { $0 < points / 140 }))
        }
        if let points = item.myPoints {
            data.record(ChallengeTurn(playerID: "me", points: points, correctCount: points / 140,
                                      bestStreak: 4, answers: (0..<10).map { $0 % 4 != 3 }))
        }
        activeRound = demoRound(for: item, data: data)
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
                                 myPoints: nil, theirPoints: nil, updated: Date())
        challenges.insert(item, at: 0)
        openDemo(item)
    }

    func newDemoChallenge() {
        let item = ChallengeItem(id: UUID().uuidString, opponentID: "riley", opponentName: "Riley",
                                 status: .yourTurn, myPoints: nil, theirPoints: nil, updated: Date())
        challenges.insert(item, at: 0)
        openDemo(item)
    }
}
