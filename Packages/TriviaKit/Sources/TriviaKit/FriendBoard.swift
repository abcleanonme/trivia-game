import Foundation

/// The Game Center leaderboards behind the Friends tab's rankings. Each
/// needs a matching leaderboard in App Store Connect with the same ID (see
/// docs/game-center-setup.md). Only friends' scores are shown in the app.
public enum FriendBoard: String, CaseIterable, Identifiable, Sendable {
    /// Today's Daily points. A recurring leaderboard that resets every day.
    case daily
    /// Best timed round in this week's event. Recurring, resets weekly.
    case weekly
    /// Current Daily streak, in days.
    case streak
    /// Friend challenges won, all time.
    case challengeWins
    /// Correct answers, all time.
    case correct
    /// Best Survival run, in correct answers.
    case survival
    /// Best Speed round, in correct answers.
    case speed

    public var id: String { rawValue }

    /// App Store Connect leaderboard ID.
    public var leaderboardID: String {
        switch self {
        case .daily: "com.abcapps.trivia.daily"
        case .weekly: "com.abcapps.trivia.weekly"
        case .streak: "com.abcapps.trivia.streak"
        case .challengeWins: "com.abcapps.trivia.challengewins"
        case .correct: "com.abcapps.trivia.correct"
        case .survival: "com.abcapps.trivia.survival"
        case .speed: "com.abcapps.trivia.speed"
        }
    }

    public var title: String {
        switch self {
        case .daily: "Today's Daily"
        case .weekly: "This week's event"
        case .streak: "Daily streak"
        case .challengeWins: "Challenge wins"
        case .correct: "Correct answers"
        case .survival: "Survival"
        case .speed: "Speed round"
        }
    }

    /// Picker label, short enough for a chip.
    public var shortTitle: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .streak: "Streak"
        case .challengeWins: "Wins"
        case .correct: "Correct"
        case .survival: "Survival"
        case .speed: "Speed"
        }
    }

    public var systemImage: String {
        switch self {
        case .daily: "calendar"
        case .weekly: "star.circle.fill"
        case .streak: "flame.fill"
        case .challengeWins: "trophy.fill"
        case .correct: "checkmark.circle.fill"
        case .survival: "heart.fill"
        case .speed: "stopwatch.fill"
        }
    }

    /// What the number means, for the row: "1,240 pts", "6 days".
    public func format(_ value: Int) -> String {
        let n = value.formatted()
        switch self {
        case .daily, .weekly: return "\(n) pts"
        case .streak: return value == 1 ? "1 day" : "\(n) days"
        case .challengeWins: return value == 1 ? "1 win" : "\(n) wins"
        case .correct, .survival, .speed: return "\(n) correct"
        }
    }

    /// One line under the board's title saying what it ranks.
    public var caption: String {
        switch self {
        case .daily: "Same ten questions for everyone today. Timed Dailies only."
        case .weekly: "Best single round in this week's event. Timed rounds only."
        case .streak: "Days in a row with a Daily played."
        case .challengeWins: "Friend challenges won, all time."
        case .correct: "Every right answer, all time."
        case .survival: "Longest Survival run."
        case .speed: "Most right in one Speed round."
        }
    }

    public var isDaily: Bool { self == .daily }

    /// Recurring boards show one period (a day or a week); the rest are all time.
    public var isRecurring: Bool { self == .daily || self == .weekly }

    /// The all-time boards, for the Friends tab. The Daily and Weekly
    /// boards live on their own tabs.
    public static let lifetime: [FriendBoard] = allCases.filter { !$0.isRecurring }

    /// The score context that marks a recurring board's period: the Daily's
    /// day ordinal, or the event's week number. `previous` steps back one
    /// period (yesterday, last week). nil for all-time boards.
    ///
    /// Game Center's periods start at a fixed UTC time, but ours start at
    /// local midnight, so every score carries its period and the app only
    /// shows the matching ones.
    public func context(today: Day, previous: Bool = false) -> Int? {
        let back = previous ? 1 : 0
        switch self {
        case .daily: return today.ordinal - back
        case .weekly: return today.weekIndex - back
        default: return nil
        }
    }

    /// The value to post for an all-time board, from local progress. nil for
    /// the Daily, which posts once when it's played.
    public func value(progress: PlayerProgress, today: Day) -> Int? {
        switch self {
        case .daily, .weekly: nil
        case .streak: progress.streak.current(on: today)
        case .challengeWins: progress.rivals.totalWins
        case .correct: progress.stats.correctAnswers
        case .survival: progress.stats.bestSurvival
        case .speed: progress.stats.bestSpeedRound
        }
    }

    /// The Daily's score for posting: timed Dailies only, so a relaxed
    /// (no clock) round never ranks against timed ones.
    public static func dailyScore(_ record: DailyRecord?) -> Int? {
        guard let record, !record.relaxed else { return nil }
        return record.points
    }

    /// This week's event score for posting: the best timed round, or nil
    /// before one has been played.
    public static func weeklyScore(_ progress: EventProgress) -> Int? {
        progress.bestRound > 0 ? progress.bestRound : nil
    }
}
