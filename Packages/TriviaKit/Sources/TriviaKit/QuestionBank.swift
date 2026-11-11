import Foundation

/// A pool of questions to deal rounds from.
///
/// For now this is a small bundled JSON file. The plan is our own bank,
/// seeded from the Open Trivia Database (with attribution) plus reviewed
/// AI-written questions, served from a backend.
public struct QuestionBank: Sendable {
    public let questions: [Question]

    public init(questions: [Question]) {
        self.questions = questions
    }

    public init(jsonData: Data) throws {
        self.questions = try JSONDecoder().decode([Question].self, from: jsonData)
    }

    /// Categories in first-seen order.
    public var categories: [String] {
        var seen = Set<String>()
        return questions.map(\.category).filter { seen.insert($0).inserted }
    }

    /// Deals a round: `count` questions plus `reserve` spares for Skip, all
    /// distinct, with answer order shuffled. Returns fewer if the pool is small.
    public func dealRound(count: Int = GameRules.questionsPerRound,
                          reserve: Int = GameRules.soloPowerUpsPerRound,
                          category: String? = nil,
                          using rng: inout some RandomNumberGenerator) -> (questions: [Question], reserve: [Question]) {
        let pool = questions
            .filter { category == nil || $0.category == category }
            .shuffled(using: &rng)
            .map { $0.shufflingChoices(using: &rng) }
        let main = Array(pool.prefix(count))
        let spare = Array(pool.dropFirst(main.count).prefix(reserve))
        return (main, spare)
    }

    public func dealRound(count: Int = GameRules.questionsPerRound,
                          reserve: Int = GameRules.soloPowerUpsPerRound,
                          category: String? = nil) -> (questions: [Question], reserve: [Question]) {
        var rng = SystemRandomNumberGenerator()
        return dealRound(count: count, reserve: reserve, category: category, using: &rng)
    }
}
