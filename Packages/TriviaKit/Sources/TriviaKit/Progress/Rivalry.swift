import Foundation

/// Head-to-head record against one friend. Kept on this device; the
/// multiplayer layer reports results here after each friend match.
public struct RivalRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable id for the friend (e.g. their Game Center player id).
    public let id: String
    public var name: String
    public var wins = 0
    public var losses = 0
    public var ties = 0
    public var lastPlayed: Date?

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public var played: Int { wins + losses + ties }

    /// "3–2" style record, with ties only when there are some.
    public var summary: String {
        ties > 0 ? "\(wins)–\(losses)–\(ties)" : "\(wins)–\(losses)"
    }
}

public enum MatchOutcome: String, Codable, Sendable { case win, loss, tie }

public struct RivalryBook: Codable, Equatable, Sendable {
    public private(set) var records: [String: RivalRecord] = [:]

    public init() {}

    public static let bigRivalWins = 10

    public func record(for friendID: String) -> RivalRecord? { records[friendID] }

    public var totalWins: Int { records.values.reduce(0) { $0 + $1.wins } }

    /// Most recently played first.
    public var sorted: [RivalRecord] {
        records.values.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    /// Adds a finished friend match. Returns stamps earned by it.
    @discardableResult
    public mutating func add(_ outcome: MatchOutcome, against friendID: String, name: String,
                             at date: Date = Date()) -> [Stamp] {
        var r = records[friendID] ?? RivalRecord(id: friendID, name: name)
        r.name = name
        r.lastPlayed = date
        switch outcome {
        case .win: r.wins += 1
        case .loss: r.losses += 1
        case .tie: r.ties += 1
        }
        records[friendID] = r
        guard outcome == .win else { return [] }
        var stamps: [Stamp] = []
        if totalWins == 1 { stamps.append(.firstRivalWin) }
        if r.wins == Self.bigRivalWins { stamps.append(.bigRivalry) }
        return stamps
    }
}
