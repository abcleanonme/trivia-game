import Foundation

public struct Question: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let category: String
    public let prompt: String
    public let choices: [String]
    public let correctIndex: Int

    public init(id: UUID = UUID(), category: String, prompt: String, choices: [String], correctIndex: Int) {
        precondition(choices.indices.contains(correctIndex), "correctIndex out of range")
        self.id = id
        self.category = category
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
    }

    public func isCorrect(_ index: Int) -> Bool { index == correctIndex }
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
