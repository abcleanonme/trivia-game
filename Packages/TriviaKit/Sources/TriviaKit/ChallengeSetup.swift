import Foundation

/// The rules a challenger picks before inviting a friend. Both players get
/// the same questions under the same rules; the friend can't change them.
public struct ChallengeSetup: Codable, Equatable, Hashable, Sendable {
    public var mode: GameMode
    public var difficulty: Difficulty
    /// The categories to draw from, in Home's order; empty for a mixed round.
    public var categories: [String]
    /// Questions in a Classic round. Survival and Speed deal a fixed pool.
    public var length: Int
    /// False plays without the per-question clock (both players). Speed
    /// round always has its round clock.
    public var isTimed: Bool
    public var powerUpLimit: Int
    /// Whether anyone in the match can invite more friends in, turning a
    /// head-to-head into a group match (or growing a group).
    public var allowsInvites: Bool

    public init(mode: GameMode = .classic, difficulty: Difficulty = .mixed, categories: [String] = [],
                length: Int = GameRules.questionsPerRound, isTimed: Bool = true,
                powerUpLimit: Int = GameRules.challengePowerUpsPerRound, allowsInvites: Bool = true) {
        self.mode = mode
        self.difficulty = difficulty
        self.categories = categories
        self.length = length
        self.isTimed = isTimed
        self.powerUpLimit = powerUpLimit
        self.allowsInvites = allowsInvites
    }

    private enum CodingKeys: String, CodingKey {
        case mode, difficulty, category, categories, length, isTimed, powerUpLimit, allowsInvites
    }

    /// Saved setups and history from before invites read as "invites on",
    /// and from before multi-category picks as their one category.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let categories = try c.decodeIfPresent([String].self, forKey: .categories)
            ?? (try c.decodeIfPresent(String.self, forKey: .category)).map { [$0] } ?? []
        self.init(mode: try c.decode(GameMode.self, forKey: .mode),
                  difficulty: try c.decode(Difficulty.self, forKey: .difficulty),
                  categories: categories,
                  length: try c.decode(Int.self, forKey: .length),
                  isTimed: try c.decode(Bool.self, forKey: .isTimed),
                  powerUpLimit: try c.decode(Int.self, forKey: .powerUpLimit),
                  allowsInvites: try c.decodeIfPresent(Bool.self, forKey: .allowsInvites) ?? true)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mode, forKey: .mode)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(categories, forKey: .categories)
        // Older builds read one category.
        if categories.count == 1 { try c.encode(categories[0], forKey: .category) }
        try c.encode(length, forKey: .length)
        try c.encode(isTimed, forKey: .isTimed)
        try c.encode(powerUpLimit, forKey: .powerUpLimit)
        try c.encode(allowsInvites, forKey: .allowsInvites)
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
        if let topic = Self.topicSummary(categories) { parts.append(topic) }
        if !hasClock { parts.append("No clock") }
        if powerUpLimit == 0 { parts.append("No power-ups") }
        if !allowsInvites { parts.append("No invites") }
        return parts.joined(separator: " · ")
    }

    /// "Science", "Science & History", "Science, History & Art", or
    /// "Science + 3 more" for longer picks; nil when mixed.
    public static func topicSummary(_ categories: [String]) -> String? {
        switch categories.count {
        case 0: return nil
        case 1: return categories[0]
        case 2: return "\(categories[0]) & \(categories[1])"
        case 3: return "\(categories[0]), \(categories[1]) & \(categories[2])"
        default: return "\(categories[0]) + \(categories.count - 1) more"
        }
    }

    /// Whether this differs from the standard 10-question mixed round.
    public var isCustom: Bool { self != .standard }

    /// Removes repeats and sorts into Home's order, so the same pick always
    /// compares equal.
    public static func ordered(_ categories: [String]) -> [String] {
        let order = QuestionBank.preferredCategoryOrder
        return Set(categories).sorted {
            (order.firstIndex(of: $0) ?? .max, $0) < (order.firstIndex(of: $1) ?? .max, $1)
        }
    }

    /// Clamps values from older saves or bad input to the allowed options.
    public func sanitized() -> ChallengeSetup {
        var s = self
        if !Self.lengths.contains(s.length) { s.length = GameRules.questionsPerRound }
        s.powerUpLimit = min(max(s.powerUpLimit, 0), Self.powerUpLimits.max()!)
        if s.mode == .speed { s.isTimed = true }
        s.categories = Self.ordered(s.categories)
        return s
    }
}
