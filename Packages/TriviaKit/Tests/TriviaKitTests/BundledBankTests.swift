import Foundation
import Testing
@testable import TriviaKit

/// Checks the question files the app ships, so a bad edit or import fails CI
/// instead of crashing a round.
@Suite struct BundledBankTests {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TriviaKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // TriviaKit
        .deletingLastPathComponent()   // Packages
        .deletingLastPathComponent()   // repo root
        .appending(path: "App/Resources")

    static func load(_ name: String) throws -> QuestionBank {
        try QuestionBank(jsonData: Data(contentsOf: resources.appending(path: "\(name).json")))
    }

    @Test(arguments: ["originals", "opentdb"])
    func everyQuestionIsPlayable(file: String) throws {
        let bank = try Self.load(file)
        #expect(!bank.questions.isEmpty)
        for q in bank.questions {
            #expect(!q.prompt.trimmingCharacters(in: .whitespaces).isEmpty, "empty prompt")
            #expect(q.choices.count == 4, "\(q.prompt)")
            #expect(Set(q.choices.map { $0.lowercased() }).count == q.choices.count, "duplicate answers: \(q.prompt)")
            #expect(QuestionBank.preferredCategoryOrder.contains(q.category), "unknown category \(q.category)")
        }
    }

    @Test func openTriviaQuestionsAreCredited() throws {
        let bank = try Self.load("opentdb")
        #expect(bank.questions.allSatisfy { $0.source?.contains("CC BY-SA 4.0") == true })
    }

    @Test func mergedBankDealsFullRoundsInEveryCategory() throws {
        let bank = QuestionBank(merging: [try Self.load("originals"), try Self.load("opentdb")])
        #expect(bank.dealRound().questions.count == GameRules.questionsPerRound)
        for category in bank.categories {
            let round = bank.dealRound(category: category)
            #expect(round.questions.count == GameRules.questionsPerRound, "\(category)")
            #expect(round.reserve.count == GameRules.soloPowerUpsPerRound, "\(category)")
        }
    }
}
