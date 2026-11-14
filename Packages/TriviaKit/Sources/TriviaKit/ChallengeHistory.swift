import Foundation

/// One finished, contested challenge, as you saw it.
public struct ChallengeGame: Codable, Equatable, Identifiable, Sendable {
    public let matchID: String
    public let opponentID: String
    public var opponentName: String
    public let outcome: ChallengeOutcome
    public let myPoints: Int
    public let theirPoints: Int
    public let myCorrect: Int
    public let theirCorrect: Int
    public let questionCount: Int
    public let setup: ChallengeSetup
    public let playedAt: Date

    public var id: String { matchID }

    public init(matchID: String, opponentID: String, opponentName: String, outcome: ChallengeOutcome,
                myPoints: Int, theirPoints: Int, myCorrect: Int, theirCorrect: Int,
                questionCount: Int, setup: ChallengeSetup, playedAt: Date) {
        self.matchID = matchID
        self.opponentID = opponentID
        self.opponentName = opponentName
        self.outcome = outcome
        self.myPoints = myPoints
        self.theirPoints = theirPoints
        self.myCorrect = myCorrect
        self.theirCorrect = theirCorrect
        self.questionCount = questionCount
        self.setup = setup
        self.playedAt = playedAt
    }

    /// Builds the entry from a finished match's data. nil unless both played.
    public init?(matchID: String, data: ChallengeData, me: String, opponentID: String,
                 opponentName: String, outcome: ChallengeOutcome, playedAt: Date) {
        guard let mine = data.turn(for: me), let theirs = data.turn(for: opponentID) else { return nil }
        self.init(matchID: matchID, opponentID: opponentID, opponentName: opponentName,
                  outcome: outcome, myPoints: mine.points, theirPoints: theirs.points,
                  myCorrect: mine.correctCount, theirCorrect: theirs.correctCount,
                  questionCount: data.questions.count, setup: data.setup, playedAt: playedAt)
    }

    /// Your points minus theirs.
    public var margin: Int { myPoints - theirPoints }
}

/// Stats for your games against one friend.
public struct HeadToHeadStats: Equatable, Sendable {
    public var played = 0
    public var wins = 0
    public var losses = 0
    public var ties = 0
    public var averageMine = 0
    public var averageTheirs = 0
    /// Biggest points margin you've won by, if you've won.
    public var biggestWin: Int?
    public var bestScore = 0
    /// Your current run: +3 is three wins in a row, -2 two losses. 0 after a tie.
    public var run = 0
    public var lastPlayed: Date?

    public init() {}

    /// "W3", "L2", or nil with no run going.
    public var runLabel: String? {
        run > 0 ? "W\(run)" : run < 0 ? "L\(-run)" : nil
    }
}

/// Every contested challenge you've finished, newest first, kept on this
/// phone. Game Center only keeps recent matches, and only while nobody has
/// removed them, so the Friends tab keeps its own history.
public struct ChallengeHistory: Codable, Equatable, Sendable {
    public private(set) var games: [ChallengeGame] = []

    /// Plenty for years of play while keeping the save small.
    public static let limit = 1_000

    public init() {}

    /// Adds a game. Returns false if that match is already in.
    @discardableResult
    public mutating func add(_ game: ChallengeGame) -> Bool {
        guard !games.contains(where: { $0.matchID == game.matchID }) else { return false }
        let at = games.firstIndex { $0.playedAt < game.playedAt } ?? games.endIndex
        games.insert(game, at: at)
        if games.count > Self.limit { games.removeLast(games.count - Self.limit) }
        return true
    }

    public func games(against opponentID: String) -> [ChallengeGame] {
        games.filter { $0.opponentID == opponentID }
    }

    public func stats(against opponentID: String) -> HeadToHeadStats {
        Self.stats(for: games(against: opponentID))
    }

    /// Stats across every friend.
    public var overall: HeadToHeadStats { Self.stats(for: games) }

    /// Friends you've played, most games first.
    public var opponents: [(id: String, name: String, games: Int)] {
        var counts: [String: (name: String, games: Int, last: Date)] = [:]
        for g in games {
            let c = counts[g.opponentID]
            // Newest first, so the first name seen is the latest one.
            counts[g.opponentID] = (c?.name ?? g.opponentName, (c?.games ?? 0) + 1, c?.last ?? g.playedAt)
        }
        return counts.map { (id: $0.key, name: $0.value.name, games: $0.value.games) }
            .sorted { $0.games != $1.games ? $0.games > $1.games : $0.name < $1.name }
    }

    /// `games` must be newest first.
    static func stats(for games: [ChallengeGame]) -> HeadToHeadStats {
        var s = HeadToHeadStats()
        guard !games.isEmpty else { return s }
        s.played = games.count
        var mine = 0, theirs = 0
        for g in games {
            switch g.outcome {
            case .won:
                s.wins += 1
                s.biggestWin = max(s.biggestWin ?? 0, g.margin)
            case .lost: s.losses += 1
            case .tied: s.ties += 1
            }
            mine += g.myPoints
            theirs += g.theirPoints
            s.bestScore = max(s.bestScore, g.myPoints)
        }
        s.averageMine = mine / games.count
        s.averageTheirs = theirs / games.count
        s.lastPlayed = games.first?.playedAt
        if let first = games.first?.outcome, first != .tied {
            let streak = games.prefix { $0.outcome == first }.count
            s.run = first == .won ? streak : -streak
        }
        return s
    }
}
