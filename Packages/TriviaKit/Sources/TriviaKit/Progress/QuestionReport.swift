import Foundation

/// A player flagging a question in play.
public struct QuestionReport: Codable, Equatable, Sendable, Identifiable {
    public enum Reason: String, Codable, CaseIterable, Sendable {
        case wrongAnswer, unclear, outdated, offensive, other

        public var label: String {
            switch self {
            case .wrongAnswer: "The answer is wrong"
            case .unclear: "The question is unclear"
            case .outdated: "It's out of date"
            case .offensive: "It's offensive"
            case .other: "Something else"
            }
        }
    }

    public let id: UUID
    public let prompt: String
    public let category: String
    public let reason: Reason
    public let reportedAt: Date

    public init(question: Question, reason: Reason, at date: Date = Date()) {
        id = UUID()
        prompt = question.prompt
        category = question.category
        self.reason = reason
        reportedAt = date
    }
}
