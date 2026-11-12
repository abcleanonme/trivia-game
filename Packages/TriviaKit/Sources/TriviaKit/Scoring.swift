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
    public static func breakdown(timeRemaining: Double?, streak: Int, powerUp: PowerUp?) -> ScoreBreakdown {
        var b = ScoreBreakdown()
        b.base = GameRules.basePoints
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
