import Foundation

/// The player's own tidying of the Friends tab, kept on the phone: friends
/// they removed from Quizio's lists and finished challenges they archived.
///
/// Game Center has no API to unfriend someone, so removing a friend hides
/// them in Quizio only. Their head-to-head record is kept, and restoring
/// them brings everything back.
public struct LobbyTidy: Codable, Equatable, Sendable {
    /// Most archived challenge IDs kept. The oldest fall off; by then
    /// Game Center has usually dropped the match anyway.
    public static let archiveLimit = 200
    /// Finished challenges older than this count as old for "Clear old".
    public static let staleAfter: TimeInterval = 7 * 24 * 60 * 60

    public private(set) var hiddenFriends: Set<String>
    /// Archived challenge IDs, oldest first.
    public private(set) var archived: [String]

    public init(hiddenFriends: Set<String> = [], archived: [String] = []) {
        self.hiddenFriends = hiddenFriends
        self.archived = archived
    }

    // MARK: Friends

    public func isHidden(_ friendID: String) -> Bool { hiddenFriends.contains(friendID) }

    public mutating func hide(_ friendID: String) { hiddenFriends.insert(friendID) }

    public mutating func unhide(_ friendID: String) { hiddenFriends.remove(friendID) }

    // MARK: Challenges

    public func isArchived(_ matchID: String) -> Bool { archived.contains(matchID) }

    public mutating func archive<S: Sequence>(_ matchIDs: S) where S.Element == String {
        for id in matchIDs where !archived.contains(id) { archived.append(id) }
        if archived.count > Self.archiveLimit { archived.removeFirst(archived.count - Self.archiveLimit) }
    }

    public mutating func unarchive(_ matchID: String) { archived.removeAll { $0 == matchID } }

    /// Forgets IDs for matches that are gone (cleared or dropped by Game Center).
    public mutating func forget<S: Sequence>(_ matchIDs: S) where S.Element == String {
        let gone = Set(matchIDs)
        archived.removeAll { gone.contains($0) }
    }

    /// Whether a finished challenge last touched at `updated` is old enough
    /// for "Clear old".
    public static func isStale(updated: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(updated) >= staleAfter
    }
}
