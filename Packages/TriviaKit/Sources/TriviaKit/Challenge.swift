import Foundation

/// How one player did on their turn of a challenge.
public struct ChallengeTurn: Codable, Equatable, Sendable {
    /// Game Center `gamePlayerID` (stable per player, per game).
    public let playerID: String
    public let points: Int
    public let correctCount: Int
    public let bestStreak: Int
    /// One entry per question, in order: true when answered correctly.
    public let answers: [Bool]
    public let playedAt: Date
    /// What they picked on each question and when, for the match breakdown
    /// and live replay. nil in turns from builds before replays.
    public let picks: [ChallengePick]?

    public init(playerID: String, points: Int, correctCount: Int, bestStreak: Int,
                answers: [Bool], playedAt: Date = Date(), picks: [ChallengePick]? = nil) {
        self.playerID = playerID
        self.points = points
        self.correctCount = correctCount
        self.bestStreak = bestStreak
        self.answers = answers
        self.playedAt = playedAt
        self.picks = picks
    }

    /// The turn a finished (or abandoned) session adds up to. Questions the
    /// player never reached count as wrong.
    public init(playerID: String, session: GameSession, playedAt: Date = Date()) {
        var answers = session.results.map(\.correct)
        if answers.count < session.questions.count {
            answers += Array(repeating: false, count: session.questions.count - answers.count)
        }
        self.init(playerID: playerID, points: session.totalPoints,
                  correctCount: session.correctCount, bestStreak: session.bestStreak,
                  answers: answers, playedAt: playedAt,
                  picks: session.results.map(ChallengePick.init(result:)))
    }
}

public enum ChallengeOutcome: String, Codable, Sendable {
    case won, lost, tied
}

/// A player's result when a match is closed out.
public enum ChallengeFinalResult: Equatable, Sendable {
    case won, lost, tied, didNotPlay
}

/// Everything a "challenge a friend" match needs, stored in the Game Center
/// turn-based match data so both phones play exactly the same round.
///
/// The challenger deals the questions (plus the spares Skip swaps in), plays,
/// and passes the turn. The friend plays the same questions in the same
/// order, and the higher score wins. Ties break on correct answers.
public struct ChallengeData: Codable, Equatable, Sendable {
    /// Bumped when the format changes, so old builds can say "update the app".
    /// Version 2 added Survival and Speed challenges. Version 3 added group
    /// matches, answer replays and Player Cards. Every new match is written
    /// as the current version, so everyone in a match is on a build that
    /// understands all of it (older builds are told to update).
    public static let currentVersion = 3

    /// Most players in one match, you included. Keeps a long round with
    /// every answer recorded well inside Game Center's 64 KB match data.
    public static let maxPlayers = 6

    public let version: Int
    public let questions: [Question]
    public let reserve: [Question]
    public let isTimed: Bool
    public let powerUpLimit: Int
    /// nil for a mixed round.
    public let category: String?
    /// nil in matches from before version 2, which were all Classic.
    private let mode: GameMode?
    /// The level the challenger picked; nil (older matches) means Mixed.
    private let difficulty: Difficulty?
    /// Whether players may invite more friends in. nil (older matches) means yes.
    private let invites: Bool?
    public private(set) var turns: [ChallengeTurn]
    /// Each player's Player Card and app build, by Game Center ID. Updated by
    /// whoever writes the match data, so opponents see each other's cards.
    public private(set) var players: [String: ChallengePlayer]?
    /// Set on a head-to-head that was turned into a group match: the ID of
    /// that group match. The head-to-head is closed without counting.
    public var movedTo: String?
    /// Set on a group match made from a head-to-head: the old match's ID.
    public var groupFrom: String?

    public init(questions: [Question], reserve: [Question], isTimed: Bool = true,
                powerUpLimit: Int = GameRules.challengePowerUpsPerRound,
                category: String? = nil, mode: GameMode = .classic,
                difficulty: Difficulty = .mixed, allowsInvites: Bool = true,
                turns: [ChallengeTurn] = []) {
        self.version = Self.currentVersion
        self.questions = questions
        self.reserve = reserve
        // A Speed round is its clock.
        self.isTimed = isTimed || mode == .speed
        self.powerUpLimit = powerUpLimit
        self.category = category
        self.mode = mode
        self.difficulty = difficulty
        self.invites = allowsInvites
        self.turns = turns
    }

    public init(setup: ChallengeSetup, questions: [Question], reserve: [Question]) {
        self.init(questions: questions, reserve: reserve, isTimed: setup.hasClock,
                  powerUpLimit: setup.powerUpLimit, category: setup.category,
                  mode: setup.mode, difficulty: setup.difficulty, allowsInvites: setup.allowsInvites)
    }

    public var gameMode: GameMode { mode ?? .classic }
    public var level: Difficulty { difficulty ?? .mixed }
    public var allowsInvites: Bool { invites ?? true }

    /// The same round, questions and turns played so far, as a new group
    /// match. Written in the current format.
    public func groupCopy(from matchID: String) -> ChallengeData {
        var copy = ChallengeData(questions: questions, reserve: reserve, isTimed: isTimed,
                                 powerUpLimit: powerUpLimit, category: category, mode: gameMode,
                                 difficulty: level, allowsInvites: allowsInvites, turns: turns)
        copy.players = players
        copy.groupFrom = matchID
        return copy
    }

    // MARK: Players

    public func player(_ playerID: String) -> ChallengePlayer? { players?[playerID] }

    /// Saves a player's card and build into the match.
    public mutating func setPlayer(_ info: ChallengePlayer, for playerID: String) {
        var all = players ?? [:]
        all[playerID] = info
        players = all
    }

    /// Other players on a newer build than `build`, so you can be told to update.
    public func playersAhead(of build: Int, me: String) -> [String] {
        (players ?? [:]).filter { $0.key != me && $0.value.build > build }.map(\.key).sorted()
    }

    /// Other players on an older build than `build`.
    public func playersBehind(_ build: Int, me: String) -> [String] {
        (players ?? [:]).filter { $0.key != me && $0.value.build < build }.map(\.key).sorted()
    }

    /// The rules this match was made with, for a rematch on the same terms.
    public var setup: ChallengeSetup {
        ChallengeSetup(mode: gameMode, difficulty: level, category: category,
                       length: gameMode == .classic ? questions.count : GameRules.questionsPerRound,
                       isTimed: isTimed, powerUpLimit: powerUpLimit, allowsInvites: allowsInvites)
    }

    // MARK: Encoding

    public init(matchData: Data) throws {
        self = try JSONDecoder.challenge.decode(Self.self, from: matchData)
    }

    public func encoded() throws -> Data {
        try JSONEncoder.challenge.encode(self)
    }

    /// Whether this build can play the match (false for a newer format).
    public var isSupported: Bool { version <= Self.currentVersion }

    // MARK: Playing

    /// A fresh session over the shared questions.
    public func makeSession() -> GameSession {
        GameSession(questions: questions, reserve: reserve,
                    isTimed: isTimed, powerUpLimit: powerUpLimit, mode: gameMode)
    }

    public func turn(for playerID: String) -> ChallengeTurn? {
        turns.first { $0.playerID == playerID }
    }

    public func hasPlayed(_ playerID: String) -> Bool { turn(for: playerID) != nil }

    /// Adds a player's turn. Returns false (and changes nothing) if they
    /// already played, so a retried submit can't overwrite a score.
    @discardableResult
    public mutating func record(_ turn: ChallengeTurn) -> Bool {
        guard !hasPlayed(turn.playerID) else { return false }
        turns.append(turn)
        return true
    }

    /// The best score so far by anyone other than `playerID`.
    public func scoreToBeat(for playerID: String) -> Int? {
        turns.filter { $0.playerID != playerID }.map(\.points).max()
    }

    // MARK: Results

    /// How `playerID` did against everyone else, once everyone in
    /// `playerIDs` has played. nil while turns are missing.
    public func outcome(for playerID: String, among playerIDs: [String]) -> ChallengeOutcome? {
        guard let mine = turn(for: playerID),
              playerIDs.allSatisfy(hasPlayed) else { return nil }
        let others = turns.filter { $0.playerID != playerID && playerIDs.contains($0.playerID) }
        guard let best = others.max(by: { Self.rank($0) < Self.rank($1) }) else { return nil }
        if Self.rank(mine) > Self.rank(best) { return .won }
        if Self.rank(mine) < Self.rank(best) { return .lost }
        return .tied
    }

    /// Everyone's final result when a match closes, which can be before
    /// everyone has played (a friend declined, quit, or ran out of time).
    /// Players with a turn are ranked against each other; if only one
    /// played, they win. Players without a turn get `.didNotPlay`.
    public func finalResults(for playerIDs: [String]) -> [String: ChallengeFinalResult] {
        let played = playerIDs.filter(hasPlayed)
        var results: [String: ChallengeFinalResult] = [:]
        for id in playerIDs {
            if !hasPlayed(id) {
                results[id] = .didNotPlay
            } else if played.count == 1 {
                results[id] = .won
            } else {
                switch outcome(for: id, among: played) {
                case .won: results[id] = .won
                case .lost: results[id] = .lost
                case .tied, nil: results[id] = .tied
                }
            }
        }
        return results
    }

    /// Whether a finished match belongs in the head-to-head record: only
    /// when both players actually played it. A declined or expired
    /// challenge isn't a real game, so it shouldn't count as anyone's win
    /// or loss.
    public func isContested(between a: String, and b: String) -> Bool {
        hasPlayed(a) && hasPlayed(b)
    }

    /// Places for everyone who played, best first. Players level on points
    /// and correct answers share a place (1, 1, 3).
    public func standings(among playerIDs: [String]) -> [(playerID: String, place: Int)] {
        let played = turns.filter { playerIDs.contains($0.playerID) }
            .sorted { Self.rank($0) > Self.rank($1) }
        var out: [(playerID: String, place: Int)] = []
        for (i, t) in played.enumerated() {
            let place = i > 0 && Self.rank(played[i - 1]) == Self.rank(t) ? out[i - 1].place : i + 1
            out.append((t.playerID, place))
        }
        return out
    }

    /// A dealt question or a spare that Skip swapped in, by ID.
    public func question(withID id: UUID) -> Question? {
        questions.first { $0.id == id } ?? reserve.first { $0.id == id }
    }

    /// Points first, then correct answers.
    private static func rank(_ turn: ChallengeTurn) -> (Int, Int) { (turn.points, turn.correctCount) }
}

extension JSONEncoder {
    public static let challenge: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
}

extension JSONDecoder {
    public static let challenge: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}
