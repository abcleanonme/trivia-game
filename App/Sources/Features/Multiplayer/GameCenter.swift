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
    private(set) var rivalries: RivalryBook
    private(set) var isLoading = false
    /// Drives the full-screen challenge cover.
    var activeRound: ChallengeRound?
    var errorMessage: String?

    @ObservationIgnored private let store: PlayerStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var matches: [String: GKTurnBasedMatch] = [:]
    @ObservationIgnored private var signInController: UIViewController?
    @ObservationIgnored private var listening = false
    @ObservationIgnored let isDemo: Bool
    private static let rivalriesKey = "rivalries.v1"

    init(store: PlayerStore, defaults: UserDefaults = .standard, demo: Bool = GameCenter.demoRequested) {
        self.store = store
        self.defaults = defaults
        self.isDemo = demo
        if let data = defaults.data(forKey: Self.rivalriesKey),
           let saved = try? JSONDecoder().decode(RivalryBook.self, from: data) {
            rivalries = saved
        } else {
            rivalries = RivalryBook()
        }
        super.init()
        if demo { loadDemo() }
    }

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

    func refresh() async {
        guard !isDemo, auth == .signedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await GKTurnBasedMatch.loadMatches()
            var items: [ChallengeItem] = []
            var byID: [String: GKTurnBasedMatch] = [:]
            for match in loaded {
                byID[match.matchID] = match
                let data = await Self.challengeData(of: match)
                if let item = await item(for: match, data: data) { items.append(item) }
            }
            matches = byID
            challenges = items.sorted { $0.updated > $1.updated }
        } catch {
            errorMessage = "Couldn't load your challenges. \(error.localizedDescription)"
        }
    }

    /// Builds the lobby row, and tidies up matches that need it: counts
    /// finished ones in the head-to-head record, and closes out a match
    /// that came back to us because the other player quit.
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
            if let outcome, let opponentID = item.opponentID {
                addToRivalries(outcome, matchID: match.matchID, opponentID: opponentID,
                               name: name, playedAt: updated)
            }
        case _ where mine?.status == .invited:
            item.status = .invited
        case _ where myTurn:
            if let data, data.hasPlayed(me) {
                // Back to us after we played: everyone else quit, so we win.
                if let finished = try? await finish(match, data: data) { return finished }
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
        guard let match = matches[item.id] else { return }
        do {
            var match = match
            if item.status == .invited {
                match = try await match.acceptInvite()
                matches[match.matchID] = match
            }
            try await show(match)
        } catch {
            errorMessage = "Couldn't open that challenge. \(error.localizedDescription)"
        }
    }

    private func show(_ match: GKTurnBasedMatch) async throws {
        let me = localPlayerID
        var data: ChallengeData
        if let existing = await Self.challengeData(of: match) {
            data = existing
        } else if match.currentParticipant?.player?.gamePlayerID == me {
            // A brand-new match we started: deal now and save straight away,
            // so backing out and coming back can't re-roll the questions.
            data = store.newChallenge()
            try await match.saveCurrentTurn(withMatch: data.encoded())
        } else {
            return
        }
        let opponent = match.participants.first { $0.player?.gamePlayerID != me }
        activeRound = ChallengeRound(
            id: match.matchID, data: data,
            opponentID: opponent?.player?.gamePlayerID,
            opponentName: opponent?.player?.displayName ?? "your opponent",
            playerIDs: match.participants.filter { $0.matchOutcome != .quit }.compactMap { $0.player?.gamePlayerID })
    }

    // MARK: Playing

    /// Saves our turn and passes the match on, or ends it if we were last.
    /// Returns the updated data so the result screen can show both scores.
    func submit(_ session: GameSession, in round: ChallengeRound) async throws -> ChallengeData {
        let turn = ChallengeTurn(playerID: localPlayerID, session: session)
        if isDemo { return submitDemo(turn, in: round) }
        guard let match = matches[round.id] else { throw ChallengeError.matchMissing }
        // Reload so a stale copy can't drop the other player's turn.
        var data = await Self.challengeData(of: match) ?? round.data
        data.record(turn)
        let me = localPlayerID
        let waiting = match.participants.filter { p in
            guard p.player?.gamePlayerID != me, p.matchOutcome != .quit,
                  p.status != .declined, p.status != .done else { return false }
            return p.player.map { !data.hasPlayed($0.gamePlayerID) } ?? true
        }
        if waiting.isEmpty {
            _ = try await finish(match, data: data)
        } else {
            match.message = "\(localPlayerName) scored \(turn.points.formatted()). Your turn!"
            try await match.endTurn(withNextParticipants: waiting,
                                    turnTimeout: GKTurnTimeoutDefault,
                                    match: data.encoded())
        }
        await refresh()
        return data
    }

    /// Sets everyone's outcome from the scores and ends the match.
    private func finish(_ match: GKTurnBasedMatch, data: ChallengeData) async throws -> ChallengeItem? {
        let active = match.participants.filter { $0.matchOutcome != .quit }
        let ids = active.compactMap { $0.player?.gamePlayerID }
        for p in active {
            guard let id = p.player?.gamePlayerID else { p.matchOutcome = .quit; continue }
            switch data.outcome(for: id, among: ids) {
            case .won: p.matchOutcome = .won
            case .lost: p.matchOutcome = .lost
            case .tied: p.matchOutcome = .tied
            // Nobody left to play against: everyone else quit.
            case nil: p.matchOutcome = ids.count == 1 ? .won : .quit
            }
        }
        match.message = "Challenge finished. See who won!"
        try await match.endMatchInTurn(withMatch: data.encoded())
        return await item(for: match, data: data)
    }

    /// Leaves a round partway: whatever was answered counts, the rest are
    /// wrong. Same as playing it out, so quitting never beats losing.
    func forfeit(_ session: GameSession, in round: ChallengeRound) async throws -> ChallengeData {
        try await submit(session, in: round)
    }

    /// Starts a new match with the same friend and opens it.
    func rematch(_ matchID: String) async {
        if isDemo { return rematchDemo(matchID) }
        guard let match = matches[matchID] else { return }
        do {
            let next = try await match.rematch()
            matches[next.matchID] = next
            try await show(next)
            await refresh()
        } catch {
            errorMessage = "Couldn't start a rematch. \(error.localizedDescription)"
        }
    }

    /// Turns down an invite, or gives up a match in progress (counts as a
    /// loss once it ends), or clears a finished one from the list.
    func remove(_ item: ChallengeItem) async {
        if isDemo {
            challenges.removeAll { $0.id == item.id }
            return
        }
        guard let match = matches[item.id] else { return }
        do {
            switch item.status {
            case .invited:
                try await match.declineInvite()
            case .yourTurn, .needsUpdate:
                let others = match.participants.filter {
                    $0.player?.gamePlayerID != localPlayerID && $0.matchOutcome != .quit
                }
                let data = try await match.loadMatchData() ?? Data()
                try await match.participantQuitInTurn(with: .quit, nextParticipants: others,
                                                      turnTimeout: GKTurnTimeoutDefault, match: data)
            case .theirTurn, .findingOpponent, .declined:
                try await match.participantQuitOutOfTurn(with: .quit)
            case .finished:
                break
            }
            if match.status == .ended || item.isFinished {
                try await match.remove()
            }
            await refresh()
        } catch {
            errorMessage = "Couldn't remove that challenge. \(error.localizedDescription)"
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

    /// nil for a match nobody has dealt yet (or data we can't read).
    private static func challengeData(of match: GKTurnBasedMatch) async -> ChallengeData? {
        guard let data = try? await match.loadMatchData(), !data.isEmpty else { return nil }
        return try? ChallengeData(matchData: data)
    }

    private func addToRivalries(_ outcome: ChallengeOutcome, matchID: String,
                                opponentID: String, name: String, playedAt: Date) {
        guard rivalries.add(outcome, matchID: matchID, opponentID: opponentID,
                            opponentName: name, playedAt: playedAt) else { return }
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
    var errorDescription: String? { "That challenge isn't available any more." }
}

// MARK: Game Center events

extension GameCenter: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        let matchID = match.matchID
        Task { @MainActor in
            await self.refresh()
            // didBecomeActive: the player tapped a notification, or just
            // picked a friend in the matchmaker. Take them straight there.
            guard didBecomeActive, let match = self.matches[matchID],
                  match.currentParticipant?.player?.gamePlayerID == self.localPlayerID else { return }
            self.dismissPresented {
                Task { try? await self.show(match) }
            }
        }
    }

    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Task { @MainActor in await self.refresh() }
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
        var book = RivalryBook()
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
