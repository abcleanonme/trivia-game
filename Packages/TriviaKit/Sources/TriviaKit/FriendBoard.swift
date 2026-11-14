import Foundation

/// The Game Center leaderboards behind the Friends tab's rankings. Each
/// needs a matching leaderboard in App Store Connect with the same ID (see
/// docs/game-center-setup.md). Only friends' scores are shown in the app.
public enum FriendBoard: String, CaseIterable, Identifiable, Sendable {
    /// Today's Daily points. A recurring leaderboard that resets every day.
    case daily
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
        case .daily: return "\(n) pts"
        case .streak: return value == 1 ? "1 day" : "\(n) days"
        case .challengeWins: return value == 1 ? "1 win" : "\(n) wins"
        case .correct, .survival, .speed: return "\(n) correct"
        }
    }

    /// Recurring boards show only the current period; the rest are all time.
    public var isDaily: Bool { self == .daily }

    /// The value to post for an all-time board, from local progress. nil for
    /// the Daily, which posts once when it's played.
    public func value(progress: PlayerProgress, today: Day, challengeWins: Int) -> Int? {
        switch self {
        case .daily: nil
        case .streak: progress.streak.current(on: today)
        case .challengeWins: challengeWins
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
}
