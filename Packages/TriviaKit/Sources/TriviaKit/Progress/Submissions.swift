import Foundation

/// A question a player wrote for the bank. Never auto-published: every one
/// is reviewed by a person first.
public struct QuestionSubmission: Codable, Equatable, Sendable, Identifiable {
    public enum Status: String, Codable, Sendable {
        /// Saved on this device, not yet delivered to the review queue.
        case queued
        case inReview
        case accepted
        case notUsed

        public var label: String {
            switch self {
            case .queued: "Waiting to send"
            case .inReview: "In review"
            case .accepted: "Accepted"
            case .notUsed: "Not used"
            }
        }
    }

    public let id: UUID
    public let prompt: String
    public let choices: [String]
    public let correctIndex: Int
    public let category: String
    public let sourceURL: URL?
    public let submittedAt: Date
    public var status: Status
    /// Set once the Sparks and title for an accepted question are paid.
    public var rewarded = false

    public static let maxPromptLength = 200
    public static let maxAnswerLength = 80
    /// Rate limit: this many submissions per rolling 24 hours.
    public static let perDay = 5
    /// Sparks for an accepted question.
    public static let acceptedSparks = 100

    public enum Problem: Error, Equatable, Sendable {
        case promptMissing, promptTooLong
        case answerMissing, answerTooLong, duplicateAnswers
        case unknownCategory, badSourceLink
        case tooMany(nextAllowed: Date)

        public var message: String {
            switch self {
            case .promptMissing: "Write the question."
            case .promptTooLong: "Keep the question under \(QuestionSubmission.maxPromptLength) characters."
            case .answerMissing: "Fill in all four answers."
            case .answerTooLong: "Keep each answer under \(QuestionSubmission.maxAnswerLength) characters."
            case .duplicateAnswers: "Each answer needs to be different."
            case .unknownCategory: "Pick a category."
            case .badSourceLink: "The source link should start with https://."
            case .tooMany(let next):
                "You've sent \(QuestionSubmission.perDay) today. Try again \(next.formatted(.relative(presentation: .named)))."
            }
        }
    }

    /// Checks the form and the rate limit, and returns a queued submission.
    public static func make(prompt: String, choices: [String], correctIndex: Int, category: String,
                            source: String, previous: [QuestionSubmission], now: Date = Date()) throws(Problem) -> QuestionSubmission {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let choices = choices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !prompt.isEmpty else { throw .promptMissing }
        guard prompt.count <= maxPromptLength else { throw .promptTooLong }
        guard choices.count == 4, choices.allSatisfy({ !$0.isEmpty }) else { throw .answerMissing }
        guard choices.allSatisfy({ $0.count <= maxAnswerLength }) else { throw .answerTooLong }
        guard Set(choices.map { $0.lowercased() }).count == 4 else { throw .duplicateAnswers }
        guard QuestionBank.preferredCategoryOrder.contains(category), choices.indices.contains(correctIndex) else {
            throw .unknownCategory
        }
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        var url: URL?
        if !source.isEmpty {
            guard let u = URL(string: source), u.scheme?.lowercased() == "https", u.host != nil else {
                throw .badSourceLink
            }
            url = u
        }
        let dayAgo = now.addingTimeInterval(-86_400)
        let recent = previous.map(\.submittedAt).filter { $0 > dayAgo }.sorted()
        if recent.count >= perDay {
            throw .tooMany(nextAllowed: recent[recent.count - perDay].addingTimeInterval(86_400))
        }
        return QuestionSubmission(id: UUID(), prompt: prompt, choices: choices, correctIndex: correctIndex,
                                  category: category, sourceURL: url, submittedAt: now, status: .queued)
    }
}

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
