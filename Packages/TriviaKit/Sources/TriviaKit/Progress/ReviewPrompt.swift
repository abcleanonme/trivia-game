import Foundation

/// When to ask for an App Store rating. Apple's prompt shows at most three
/// times a year on its own, but we ask far less than that: only right after
/// a good moment, never on a player's first day, and with long gaps between.
public struct ReviewPrompt: Codable, Equatable, Sendable {
    /// Days the app has been used to finish a round (distinct local days).
    public private(set) var activeDays: [Day] = []
    /// Good moments seen since the last ask.
    public private(set) var goodMoments = 0
    /// When we last asked, and for which app version.
    public private(set) var lastAsked: Day?
    public private(set) var lastAskedVersion: String?
    /// Recent challenge wins already counted, so reopening one doesn't count again.
    public private(set) var countedMatches: [String] = []

    public init() {}

    /// Distinct days needed before the first ask, so it's never the first session.
    public static let minActiveDays = 2
    /// Good moments needed before an ask (counted fresh after each ask).
    public static let minGoodMoments = 3
    /// Days between asks.
    public static let cooldownDays = 120

    public enum Moment: Sendable, Equatable {
        /// A solo round: correct answers out of questions asked.
        case round(correct: Int, of: Int)
        /// A friend or group challenge where the player came first.
        case challengeWin(matchID: String)
    }

    /// Whether a moment is good enough to count. Solo rounds need 5+ questions
    /// and at least 80% right, so a short or rough round never counts.
    public static func isGood(_ moment: Moment) -> Bool {
        switch moment {
        case .challengeWin: return true
        case let .round(correct, total):
            return total >= 5 && Double(correct) >= Double(total) * 0.8
        }
    }

    /// Notes that a round finished today, whatever the result.
    public mutating func notePlayed(on day: Day) {
        if !activeDays.contains(day) {
            activeDays.append(day)
            // Only the count matters; keep the list short.
            if activeDays.count > Self.minActiveDays { activeDays.removeFirst() }
        }
    }

    /// Records a moment and says whether to ask now. When it returns true
    /// the ask is recorded, so call it once per moment.
    public mutating func shouldAsk(after moment: Moment, on day: Day, version: String) -> Bool {
        notePlayed(on: day)
        guard Self.isGood(moment) else { return false }
        if case let .challengeWin(id) = moment {
            guard !countedMatches.contains(id) else { return false }
            countedMatches.append(id)
            if countedMatches.count > 20 { countedMatches.removeFirst() }
        }
        goodMoments += 1
        // Today is always in the list, so two days means an earlier one too.
        guard activeDays.count >= Self.minActiveDays,
              goodMoments >= Self.minGoodMoments,
              lastAskedVersion != version
        else { return false }
        if let lastAsked, day.ordinal - lastAsked.ordinal < Self.cooldownDays { return false }
        lastAsked = day
        lastAskedVersion = version
        goodMoments = 0
        return true
    }
}
