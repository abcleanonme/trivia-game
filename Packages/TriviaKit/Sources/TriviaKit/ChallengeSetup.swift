import Foundation

/// The rules a challenger picks before inviting a friend. Both players get
/// the same questions under the same rules; the friend can't change them.
public struct ChallengeSetup: Codable, Equatable, Hashable, Sendable {
    public var mode: GameMode
    public var difficulty: Difficulty
    /// nil for a mixed round.
    public var category: String?
    /// Questions in a Classic round. Survival and Speed deal a fixed pool.
    public var length: Int
    /// False plays without the per-question clock (both players). Speed
    /// round always has its round clock.
    public var isTimed: Bool
    public var powerUpLimit: Int

    public init(mode: GameMode = .classic, difficulty: Difficulty = .mixed, category: String? = nil,
                length: Int = GameRules.questionsPerRound, isTimed: Bool = true,
                powerUpLimit: Int = GameRules.challengePowerUpsPerRound) {
        self.mode = mode
        self.difficulty = difficulty
        self.category = category
        self.length = length
        self.isTimed = isTimed
        self.powerUpLimit = powerUpLimit
    }

    public static let standard = ChallengeSetup()

    public static let lengths = [5, 10, 15]
    public static let powerUpLimits = [0, 1, 2, 3]

    /// Questions dealt up front. Survival and Speed get a capped pool so the
    /// whole round fits in Game Center's 64 KB match data.
    public static let longRoundPool = 40

    public var questionCount: Int {
        switch mode {
        case .classic: Self.lengths.contains(length) ? length : GameRules.questionsPerRound
        case .survival, .speed: Self.longRoundPool
        }
    }

    /// Spares for Skip: one per power-up allowed.
    public var reserveCount: Int { max(powerUpLimit, 0) }

    /// Speed round is its clock, so it can't be untimed.
    public var hasClock: Bool { isTimed || mode == .speed }

    /// Short line for rows and the invite: "Hard · Science · 15 questions".
    public var summary: String {
        var parts: [String] = []
        switch mode {
        case .classic: parts.append("\(questionCount) questions")
        case .survival: parts.append("Survival")
        case .speed: parts.append("Speed round")
        }
        if difficulty != .mixed { parts.append(difficulty.title) }
        if let category { parts.append(category) }
        if !hasClock { parts.append("No clock") }
        if powerUpLimit == 0 { parts.append("No power-ups") }
        return parts.joined(separator: " · ")
    }

    /// Whether this differs from the standard 10-question mixed round.
    public var isCustom: Bool { self != .standard }

    /// Clamps values from older saves or bad input to the allowed options.
    public func sanitized() -> ChallengeSetup {
        var s = self
        if !Self.lengths.contains(s.length) { s.length = GameRules.questionsPerRound }
        s.powerUpLimit = min(max(s.powerUpLimit, 0), Self.powerUpLimits.max()!)
        if s.mode == .speed { s.isTimed = true }
        return s
    }
}
