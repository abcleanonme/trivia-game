import Foundation

/// Pure game logic for a single round. Shared by solo and multiplayer modes.
public struct GameSession: Sendable {
    public enum State: Equatable, Sendable {
        case asking(index: Int)
        case answered(index: Int, choice: Int, correct: Bool)
        case finished
    }

    public let questions: [Question]
    public private(set) var state: State
    public private(set) var score: Int = 0

    public init(questions: [Question]) {
        self.questions = questions
        self.state = questions.isEmpty ? .finished : .asking(index: 0)
    }

    public var currentQuestion: Question? {
        switch state {
        case .asking(let i), .answered(let i, _, _): questions[i]
        case .finished: nil
        }
    }

    public mutating func answer(_ choice: Int) {
        guard case .asking(let i) = state else { return }
        let correct = questions[i].isCorrect(choice)
        if correct { score += 1 }
        state = .answered(index: i, choice: choice, correct: correct)
    }

    public mutating func advance() {
        guard case .answered(let i, _, _) = state else { return }
        state = i + 1 < questions.count ? .asking(index: i + 1) : .finished
    }
}
