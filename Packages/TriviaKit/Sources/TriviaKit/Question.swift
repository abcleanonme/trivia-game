import Foundation

public struct Question: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let category: String
    public let prompt: String
    public let choices: [String]
    public let correctIndex: Int
    /// "easy", "medium" or "hard" when known.
    public let difficulty: String?
    /// Attribution for the question's origin (e.g. "Open Trivia Database,
    /// CC BY-SA 4.0"). Shown in credits; required for OpenTDB questions.
    public let source: String?

    public init(id: UUID = UUID(), category: String, prompt: String, choices: [String],
                correctIndex: Int, difficulty: String? = nil, source: String? = nil) {
        precondition(choices.indices.contains(correctIndex), "correctIndex out of range")
        self.id = id
        self.category = category
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.difficulty = difficulty
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, prompt, choices, correctIndex, difficulty, source
    }

    /// Bundled JSON may omit `id`; one is generated at load time.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let choices = try c.decode([String].self, forKey: .choices)
        let correctIndex = try c.decode(Int.self, forKey: .correctIndex)
        guard choices.indices.contains(correctIndex) else {
            throw DecodingError.dataCorruptedError(forKey: .correctIndex, in: c,
                                                   debugDescription: "correctIndex out of range")
        }
        self.init(id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                  category: try c.decode(String.self, forKey: .category),
                  prompt: try c.decode(String.self, forKey: .prompt),
                  choices: choices,
                  correctIndex: correctIndex,
                  difficulty: try c.decodeIfPresent(String.self, forKey: .difficulty),
                  source: try c.decodeIfPresent(String.self, forKey: .source))
    }

    public func isCorrect(_ index: Int) -> Bool { index == correctIndex }

    public var correctAnswer: String { choices[correctIndex] }

    /// The same question with its answers in a random order, so the right
    /// answer isn't always in the same slot.
    public func shufflingChoices(using rng: inout some RandomNumberGenerator) -> Question {
        let order = choices.indices.shuffled(using: &rng)
        return Question(id: id, category: category, prompt: prompt,
                        choices: order.map { choices[$0] },
                        correctIndex: order.firstIndex(of: correctIndex)!,
                        difficulty: difficulty,
                        source: source)
    }
}

public extension Question {
    static let samples: [Question] = [
        Question(category: "Science", prompt: "What planet is known as the Red Planet?",
                 choices: ["Venus", "Mars", "Jupiter", "Mercury"], correctIndex: 1),
        Question(category: "Geography", prompt: "What is the capital of Australia?",
                 choices: ["Sydney", "Melbourne", "Canberra", "Perth"], correctIndex: 2),
        Question(category: "History", prompt: "In what year did the first Moon landing happen?",
                 choices: ["1965", "1969", "1972", "1959"], correctIndex: 1),
    ]
}
