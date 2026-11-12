import Foundation

/// Milestones earned only by playing, never sold. Each can sit in the corner
/// of the Player Card, and most also grant a title.
public enum Stamp: Hashable, Codable, Sendable, Identifiable {
    case perfectRound
    /// 10 correct in a row in one round.
    case tenStreak
    /// 5 correct answers within 5 seconds each in one round.
    case speedDemon
    /// 7, 30 or 100 Dailies in a row.
    case dailyStreak(Int)
    case hundredDailies
    case firstRivalWin
    /// 10 wins against the same friend.
    case bigRivalry
    case fiftyWins
    case questionWriter
    case eventComplete(String)
    /// Category mastery level 5 or 10.
    case mastery(category: String, level: Int)

    public static let dailyStreakSteps = [7, 30, 100]

    public var id: String {
        switch self {
        case .perfectRound: "perfect"
        case .tenStreak: "streak10"
        case .speedDemon: "speed"
        case .dailyStreak(let n): "daily\(n)"
        case .hundredDailies: "dailies100"
        case .firstRivalWin: "rival1"
        case .bigRivalry: "rival10"
        case .fiftyWins: "wins50"
        case .questionWriter: "writer"
        case .eventComplete(let e): "event.\(e)"
        case .mastery(let c, let l): "mastery.\(c).\(l)"
        }
    }

    public var name: String {
        switch self {
        case .perfectRound: "Perfect round"
        case .tenStreak: "10 in a row"
        case .speedDemon: "Lightning fingers"
        case .dailyStreak(let n): "\(n)-day Daily streak"
        case .hundredDailies: "100 Dailies"
        case .firstRivalWin: "First friend win"
        case .bigRivalry: "\(RivalryBook.bigRivalWins) wins vs one friend"
        case .fiftyWins: "50 match wins"
        case .questionWriter: "Question accepted"
        case .eventComplete(let e): "\(WeeklyEvent.all.first { $0.id == e }?.title ?? "Event") complete"
        case .mastery(let c, let l): "\(c) level \(l)"
        }
    }

    public var systemImage: String {
        switch self {
        case .perfectRound: "star.circle.fill"
        case .tenStreak: "flame.fill"
        case .speedDemon: "bolt.circle.fill"
        case .dailyStreak: "calendar.badge.checkmark"
        case .hundredDailies: "calendar.circle.fill"
        case .firstRivalWin: "person.2.fill"
        case .bigRivalry: "figure.fencing"
        case .fiftyWins: "trophy.fill"
        case .questionWriter: "pencil.and.scribble"
        case .eventComplete: "flag.checkered"
        case .mastery(_, let l): l >= 10 ? "rosette" : "medal.fill"
        }
    }

    /// The title this stamp unlocks, if any. Titles are earned, never bought.
    public var title: String? {
        switch self {
        case .perfectRound: "Big Brain"
        case .tenStreak: "Streak Machine"
        case .speedDemon: "Speed Demon"
        case .dailyStreak(30): "Daily Devotee"
        case .dailyStreak(100): "Daily Legend"
        case .hundredDailies: "Regular"
        case .bigRivalry: "Arch Rival"
        case .fiftyWins: "Champion"
        case .questionWriter: "Question Writer"
        case .mastery(let c, 5): "\(c) Buff"
        case .mastery(let c, 10): "\(c) Master"
        default: nil
        }
    }

    public static let defaultTitle = "Trivia Fan"
}
