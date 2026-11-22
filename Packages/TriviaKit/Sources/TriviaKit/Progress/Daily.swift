import Foundation

/// The Daily challenge: the same ten questions for everyone on a date, one
/// attempt, a day streak, and a spoiler-free share card.
public enum DailyChallenge {
    public static let finishBonus = 50
    public static let perfectBonus = 100
    /// Answers faster than this get the yellow ring on the share card.
    public static let fastAnswerSeconds: Double = 5

    /// Sparks on top of the normal 1-per-10-points for finishing the Daily.
    /// A perfect 10/10 pays the bigger bonus instead of the normal one.
    public static func bonus(correct: Int, total: Int) -> Int {
        total > 0 && correct == total ? perfectBonus : finishBonus
    }

    /// Deals the day's round. Deterministic: depends only on the date and the
    /// bank's contents (not its order or load-time ids), so every copy of the
    /// same app version deals the same questions in the same order with the
    /// same answer order.
    public static func round(for day: Day, from bank: QuestionBank) -> (questions: [Question], reserve: [Question]) {
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(day.ordinal)) &* 0x2545_F491_4F6C_DD1D)
        let stable = bank.questions.sorted { $0.prompt.lowercased() < $1.prompt.lowercased() }
        return QuestionBank(questions: stable).dealRound(using: &rng)
    }
}

/// One square on the share card.
public struct DailyMark: Codable, Equatable, Sendable {
    public let correct: Bool
    /// Answered within `DailyChallenge.fastAnswerSeconds`.
    public let fast: Bool

    public init(correct: Bool, fast: Bool) {
        self.correct = correct
        self.fast = fast
    }

    public init(_ result: QuestionResult) {
        var fast = false
        if let left = result.timeRemaining, !result.timedOut {
            let clock = GameRules.questionTime + (result.powerUp == .extraTime ? GameRules.extraTimeSeconds : 0)
            fast = clock - left < DailyChallenge.fastAnswerSeconds
        }
        self.init(correct: result.correct, fast: fast)
    }
}

/// What the player did on one day's Daily.
public struct DailyRecord: Codable, Equatable, Sendable {
    public let day: Day
    public var marks: [DailyMark]
    public var points: Int
    /// Played with no clock; marked as such wherever scores are compared.
    public var relaxed: Bool
    /// False when the player left before the last question. The attempt still
    /// counts (one try per day), but it doesn't extend the streak.
    public var finished: Bool
    /// Day streak after this Daily, for the share card.
    public var streak: Int

    public init(day: Day, marks: [DailyMark] = [], points: Int = 0, relaxed: Bool,
                finished: Bool = false, streak: Int = 0) {
        self.day = day
        self.marks = marks
        self.points = points
        self.relaxed = relaxed
        self.finished = finished
        self.streak = streak
    }

    public var correct: Int { marks.filter(\.correct).count }

    /// Text that goes with the share-card image. No question text, so it
    /// can't spoil anyone's Daily.
    public var shareText: String {
        let grid = marks.map { $0.correct ? "🟦" : "🟧" }.joined()
        let fast = marks.filter(\.fast).count
        var lines = ["Quizio Daily #\(day.dailyNumber)\(relaxed ? " (relaxed)" : "")",
                     "\(grid)  \(correct)/\(marks.count)",
                     "\(points.formatted(.number)) pts" + (fast > 0 ? " · ⚡\(fast) fast" : "")]
        if streak > 1 { lines.append("🔥 \(streak)-day streak") }
        return lines.joined(separator: "\n")
    }
}

/// Days in a row the player has finished the Daily.
///
/// One "streak freeze" can be held at a time. It's earned (never bought) by
/// every 7 days in a row, and it covers one missed day automatically.
public struct DailyStreak: Codable, Equatable, Sendable {
    public private(set) var lastPlayed: Day?
    public private(set) var count = 0
    public private(set) var best = 0
    public private(set) var freezes = 0

    public static let maxFreezes = 1
    public static let daysPerFreeze = 7

    public init() {}

    /// The streak as it stands today: still alive if the player played
    /// yesterday (or today), or if freezes cover the missed days.
    public func current(on today: Day) -> Int {
        guard let lastPlayed else { return 0 }
        let missed = today - lastPlayed - 1
        return missed <= freezes ? count : 0
    }

    public enum Change: Equatable, Sendable {
        case sameDay, extended, frozeAndExtended(missed: Int), restarted
    }

    /// Records a finished Daily.
    @discardableResult
    public mutating func record(_ day: Day) -> Change {
        let change: Change
        if let lastPlayed {
            let gap = day - lastPlayed
            if gap <= 0 { return .sameDay }
            let missed = gap - 1
            if missed == 0 {
                count += 1
                change = .extended
            } else if missed <= freezes {
                freezes -= missed
                count += 1
                change = .frozeAndExtended(missed: missed)
            } else {
                count = 1
                change = .restarted
            }
        } else {
            count = 1
            change = .restarted
        }
        lastPlayed = day
        best = max(best, count)
        if count % Self.daysPerFreeze == 0 {
            freezes = min(freezes + 1, Self.maxFreezes)
        }
        return change
    }
}
