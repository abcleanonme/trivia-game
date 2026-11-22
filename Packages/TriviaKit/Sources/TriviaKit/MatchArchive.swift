import Foundation

/// A finished match kept on this phone so its breakdown and replay can be
/// watched later, even after it's cleared from Game Center.
public struct ArchivedMatch: Codable, Equatable, Identifiable, Sendable {
    public let matchID: String
    public let data: ChallengeData
    /// Everyone in the match, in seat order, you included.
    public let playerIDs: [String]
    /// Game Center display names by player ID.
    public var names: [String: String]
    public let finishedAt: Date

    public var id: String { matchID }

    public init(matchID: String, data: ChallengeData, playerIDs: [String],
                names: [String: String], finishedAt: Date) {
        self.matchID = matchID
        self.data = data
        self.playerIDs = playerIDs
        self.names = names
        self.finishedAt = finishedAt
    }

    public var isGroup: Bool { playerIDs.count > 2 }
}

/// The most recent finished matches, newest first.
public struct MatchArchive: Codable, Equatable, Sendable {
    public private(set) var matches: [ArchivedMatch] = []

    /// Each match is a few KB, so this stays well under a megabyte.
    public static let limit = 60

    public init() {}

    /// Adds or refreshes a match. Returns false when nothing changed.
    @discardableResult
    public mutating func add(_ match: ArchivedMatch) -> Bool {
        if let i = matches.firstIndex(where: { $0.matchID == match.matchID }) {
            guard matches[i] != match else { return false }
            matches.remove(at: i)
        }
        let at = matches.firstIndex { $0.finishedAt < match.finishedAt } ?? matches.endIndex
        matches.insert(match, at: at)
        if matches.count > Self.limit { matches.removeLast(matches.count - Self.limit) }
        return true
    }

    public func match(_ matchID: String) -> ArchivedMatch? {
        matches.first { $0.matchID == matchID }
    }

    /// Finished group matches, newest first.
    public var groups: [ArchivedMatch] { matches.filter(\.isGroup) }
}
