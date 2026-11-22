import Foundation

public enum GameRules {
    /// Seconds on the clock for each question.
    public static let questionTime: Double = 20
    public static let extraTimeSeconds: Double = 10
    public static let basePoints = 100
    public static let maxSpeedBonus = 50
    public static let soloPowerUpsPerRound = 3
    /// Friend challenges use your own stock, like casual multiplayer.
    public static let challengePowerUpsPerRound = 2
    public static let questionsPerRound = 10
    /// 1 Spark per this many points.
    public static let pointsPerSpark = 10
}

/// How the points for one question were made up. Shown on the feedback bar
/// and summed on the round summary.
public struct ScoreBreakdown: Equatable, Sendable {
    public var base = 0
    public var speed = 0
    public var streakBonus = 0
    /// Double down adds, second chance halves (negative).
    public var powerUpAdjustment = 0

    public var total: Int { base + speed + streakBonus + powerUpAdjustment }

    public static let zero = ScoreBreakdown()

    public static func + (lhs: Self, rhs: Self) -> Self {
        ScoreBreakdown(base: lhs.base + rhs.base,
                       speed: lhs.speed + rhs.speed,
                       streakBonus: lhs.streakBonus + rhs.streakBonus,
                       powerUpAdjustment: lhs.powerUpAdjustment + rhs.powerUpAdjustment)
    }
}

/// The difficulty picker before a round. Every question also pays by its
/// own tag, so a hard question in a Mixed round is worth hard points too.
public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case mixed, easy, medium, hard

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The bank's tag to filter on, or nil for any.
    public var tag: String? { self == .mixed ? nil : rawValue }

    public static func basePoints(for tag: String?) -> Int {
        switch tag {
        case "medium": 125
        case "hard": 150
        default: GameRules.basePoints
        }
    }

    public var summary: String {
        switch self {
        case .mixed: "A bit of everything"
        case .easy: "\(Self.basePoints(for: "easy")) points a question"
        case .medium: "\(Self.basePoints(for: "medium")) points a question"
        case .hard: "\(Self.basePoints(for: "hard")) points a question"
        }
    }
}

/// How a round runs. Relaxed (no clock) is a separate toggle that works
/// with any mode except Speed round, which *is* a clock.
public enum GameMode: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 10 questions, 20 seconds each.
    case classic
    /// Keep going until the third wrong answer.
    case survival
    /// As many as you can in 60 seconds; no stopping between questions.
    case speed

    public var id: String { rawValue }

    public static let survivalStrikes = 3
    public static let speedRoundSeconds: Double = 60

    public var title: String {
        switch self {
        case .classic: "Classic"
        case .survival: "Survival"
        case .speed: "Speed round"
        }
    }

    public var summary: String {
        switch self {
        case .classic: "10 questions, 20 seconds each."
        case .survival: "Keep going until you miss \(Self.survivalStrikes)."
        case .speed: "As many as you can in \(Int(Self.speedRoundSeconds)) seconds."
        }
    }

    public var systemImage: String {
        switch self {
        case .classic: "list.number"
        case .survival: "heart.fill"
        case .speed: "stopwatch.fill"
        }
    }

    public var supportsRelaxed: Bool { self != .speed }

    /// Questions dealt up front.
    public var questionCount: Int {
        switch self {
        case .classic: GameRules.questionsPerRound
        case .survival: 150
        case .speed: 120
        }
    }
}

public enum Scoring {
    /// Streak multiplier for a correct answer, where `streak` already
    /// includes that answer: x1.5 from 3 in a row, x2 from 5 in a row.
    public static func multiplier(forStreak streak: Int) -> Double {
        switch streak {
        case 5...: 2
        case 3...: 1.5
        default: 1
        }
    }

    /// Points for one correct answer.
    /// - Parameters:
    ///   - timeRemaining: seconds left when answered (nil in relaxed mode).
    ///   - streak: the streak *including* this answer.
    ///   - powerUp: the power-up used on this question, if any.
    ///   - difficulty: the question's tag; medium and hard are worth more.
    public static func breakdown(timeRemaining: Double?, streak: Int, powerUp: PowerUp?,
                                 difficulty: String? = nil) -> ScoreBreakdown {
        var b = ScoreBreakdown()
        b.base = Difficulty.basePoints(for: difficulty)
        // Any power-up forfeits the speed bonus; relaxed mode has none.
        if powerUp == nil, let timeRemaining {
            let fraction = min(max(timeRemaining / GameRules.questionTime, 0), 1)
            b.speed = Int((Double(GameRules.maxSpeedBonus) * fraction).rounded())
        }
        let subtotal = b.base + b.speed
        let withStreak = Int((Double(subtotal) * multiplier(forStreak: streak)).rounded())
        b.streakBonus = withStreak - subtotal
        switch powerUp {
        case .doubleDown: b.powerUpAdjustment = withStreak
        case .secondChance: b.powerUpAdjustment = -(withStreak - withStreak / 2)
        default: break
        }
        return b
    }

    public static func sparks(forPoints points: Int) -> Int {
        max(points, 0) / GameRules.pointsPerSpark
    }
}
