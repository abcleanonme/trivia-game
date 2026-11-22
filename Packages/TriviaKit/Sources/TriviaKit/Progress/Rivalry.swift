import Foundation

/// Head-to-head record against one friend. Kept on this device; the
/// multiplayer layer reports results here after each friend match.
public struct RivalRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable id for the friend (e.g. their Game Center player id).
    public let id: String
    /// Their name when we last played, for showing offline.
    public var name: String
    public var wins = 0
    public var losses = 0
    public var ties = 0
    public var lastPlayed: Date?

    public init(id: String, name: String, wins: Int = 0, losses: Int = 0, ties: Int = 0, lastPlayed: Date? = nil) {
        self.id = id
        self.name = name
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.lastPlayed = lastPlayed
    }

    public var played: Int { wins + losses + ties }

    /// "3–2" style record, with ties only when there are some.
    public var summary: String {
        ties > 0 ? "\(wins)–\(losses)–\(ties)" : "\(wins)–\(losses)"
    }
}

/// Head-to-head records against every friend. The one source of truth for
/// the Friends tab, Profile, rivalry stamps and the challenge-wins board.
public struct RivalryBook: Codable, Equatable, Sendable {
    public private(set) var records: [String: RivalRecord] = [:]
    /// Game Center hands back the same finished matches on every refresh,
    /// so each match ID counts once.
    private var countedMatchIDs: Set<String> = []

    public init() {}

    public static let bigRivalWins = 10

    public func record(for friendID: String) -> RivalRecord? { records[friendID] }

    public var totalWins: Int { records.values.reduce(0) { $0 + $1.wins } }

    /// Most recently played first.
    public var sorted: [RivalRecord] {
        records.values.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    public func hasCounted(matchID: String) -> Bool { countedMatchIDs.contains(matchID) }

    /// Marks matches as already counted without changing any record (used
    /// to carry over the dedupe list from older builds).
    public mutating func markCounted<S: Sequence>(_ matchIDs: S) where S.Element == String {
        countedMatchIDs.formUnion(matchIDs)
    }

    /// Adds a finished friend match. Returns the stamps it earned, or nil
    /// if this match was already counted.
    @discardableResult
    public mutating func add(_ outcome: ChallengeOutcome, against friendID: String, name: String,
                             matchID: String? = nil, at date: Date = Date()) -> [Stamp]? {
        if let matchID, !countedMatchIDs.insert(matchID).inserted { return nil }
        var r = records[friendID] ?? RivalRecord(id: friendID, name: name)
        r.name = name
        r.lastPlayed = max(r.lastPlayed ?? date, date)
        switch outcome {
        case .won: r.wins += 1
        case .lost: r.losses += 1
        case .tied: r.ties += 1
        }
        records[friendID] = r
        guard outcome == .won else { return [] }
        var stamps: [Stamp] = []
        if totalWins == 1 { stamps.append(.firstRivalWin) }
        if r.wins == Self.bigRivalWins { stamps.append(.bigRivalry) }
        return stamps
    }

    private enum CodingKeys: String, CodingKey { case records, countedMatchIDs }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        records = try c.decodeIfPresent([String: RivalRecord].self, forKey: .records) ?? [:]
        countedMatchIDs = try c.decodeIfPresent(Set<String>.self, forKey: .countedMatchIDs) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(records, forKey: .records)
        try c.encode(countedMatchIDs, forKey: .countedMatchIDs)
    }
}
