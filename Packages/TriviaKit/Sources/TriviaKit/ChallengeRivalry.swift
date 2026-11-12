import Foundation

/// Your running record against one friend.
public struct HeadToHead: Codable, Equatable, Sendable {
    public var wins = 0
    public var losses = 0
    public var ties = 0
    /// Their Game Center name when we last played, for showing offline.
    public var displayName: String
    public var lastPlayed: Date?

    public init(displayName: String, wins: Int = 0, losses: Int = 0, ties: Int = 0, lastPlayed: Date? = nil) {
        self.displayName = displayName
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.lastPlayed = lastPlayed
    }

    public var played: Int { wins + losses + ties }

    /// "3–1", or "3–1–2" when there are ties.
    public var summary: String {
        ties > 0 ? "\(wins)–\(losses)–\(ties)" : "\(wins)–\(losses)"
    }
}

/// Head-to-head records against every friend you've finished a challenge
/// with. Each match counts once, however many times it's seen, because Game
/// Center hands back the same finished matches on every refresh.
public struct ChallengeRivalryBook: Codable, Equatable, Sendable {
    public private(set) var records: [String: HeadToHead] = [:]
    private var countedMatchIDs: Set<String> = []

    public init() {}

    public func record(against opponentID: String) -> HeadToHead? { records[opponentID] }

    /// Rivals, most recently played first.
    public var rivals: [(id: String, record: HeadToHead)] {
        records.map { (id: $0.key, record: $0.value) }
            .sorted { ($0.record.lastPlayed ?? .distantPast) > ($1.record.lastPlayed ?? .distantPast) }
    }

    public func hasCounted(matchID: String) -> Bool { countedMatchIDs.contains(matchID) }

    /// Adds a finished match. Returns false if it was already counted.
    @discardableResult
    public mutating func add(_ outcome: ChallengeOutcome, matchID: String,
                             opponentID: String, opponentName: String,
                             playedAt: Date = Date()) -> Bool {
        guard countedMatchIDs.insert(matchID).inserted else { return false }
        var r = records[opponentID] ?? HeadToHead(displayName: opponentName)
        switch outcome {
        case .won: r.wins += 1
        case .lost: r.losses += 1
        case .tied: r.ties += 1
        }
        r.displayName = opponentName
        r.lastPlayed = max(r.lastPlayed ?? playedAt, playedAt)
        records[opponentID] = r
        return true
    }
}
