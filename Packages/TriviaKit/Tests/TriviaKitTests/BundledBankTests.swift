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

    @Test(arguments: ["originals", "originals-ai", "opentdb", "events"])
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

    /// Event questions only play in their event, so each must name a real
    /// one, and none should repeat a question already in the main bank.
    @Test func eventQuestionsAreTaggedAndNew() throws {
        let events = try Self.load("events")
        let ids = Set(WeeklyEvent.all.map(\.id))
        let main = Set(QuestionBank(merging: [try Self.load("originals"), try Self.load("originals-ai"),
                                              try Self.load("opentdb")]).questions.map { $0.prompt.lowercased() })
        var prompts = Set<String>()
        for q in events.questions {
            #expect(ids.contains(q.event ?? ""), "untagged or unknown event: \(q.prompt)")
            #expect(["easy", "medium", "hard"].contains(q.difficulty ?? ""), "\(q.prompt)")
            #expect(q.source?.contains("Quizio original") == true, "\(q.prompt)")
            #expect(!main.contains(q.prompt.lowercased()), "already in the main bank: \(q.prompt)")
            #expect(prompts.insert(q.prompt.lowercased()).inserted, "repeated: \(q.prompt)")
        }
        // The main bank stays untagged, so event questions never leak into
        // everyday rounds.
        for file in ["originals", "originals-ai", "opentdb"] {
            #expect(try Self.load(file).questions.allSatisfy { $0.event == nil }, "\(file)")
        }
    }

    @Test func openTriviaQuestionsAreCredited() throws {
        let bank = try Self.load("opentdb")
        #expect(bank.questions.allSatisfy { $0.source?.contains("CC BY-SA 4.0") == true })
    }

    @Test func aiDraftsHaveDifficultyAndAreLabeled() throws {
        let bank = try Self.load("originals-ai")
        for q in bank.questions {
            #expect(["easy", "medium", "hard"].contains(q.difficulty ?? ""), "\(q.prompt)")
            #expect(q.source?.contains("AI-drafted") == true, "\(q.prompt)")
        }
    }

    /// The categories the app launched with. Thin categories repeat fast,
    /// so these stay deep enough for several rounds per difficulty.
    static let establishedCategories = [
        "General", "Science", "History", "Geography", "Movies", "TV", "Music",
        "Sports", "Games", "Books", "Art", "Nature", "Tech", "Pop Culture", "Anime",
    ]

    @Test func establishedCategoriesHaveADeepPool() throws {
        let bank = QuestionBank(merging: [try Self.load("originals"), try Self.load("originals-ai"), try Self.load("opentdb")])
        for category in Self.establishedCategories {
            #expect(bank.count(in: category) >= 150, "\(category) has \(bank.count(in: category))")
        }
    }

    /// Newer categories (Food, Space, Mythology...) only show up as picks
    /// once they're deep enough; until then their questions play in mixes.
    @Test func onlyDeepCategoriesArePickable() throws {
        let bank = QuestionBank(merging: [try Self.load("originals"), try Self.load("originals-ai"), try Self.load("opentdb")])
        for category in bank.categories {
            let deep = bank.count(in: category) >= QuestionBank.minimumCategorySize
            #expect(bank.playableCategories.contains(category) == deep, "\(category)")
        }
        for category in ["Mythology", "Cartoons", "Comics", "Vehicles"] {
            #expect(bank.playableCategories.contains(category), "\(category)")
        }
    }

    /// Mixed rounds lean easy, so the bank needs plenty of easy and medium
    /// questions, not just hard ones.
    @Test func mixedRoundsHaveEnoughEasierQuestions() throws {
        let bank = QuestionBank(merging: [try Self.load("originals"), try Self.load("originals-ai"), try Self.load("opentdb")])
        let easy = bank.questions.filter { $0.difficulty == "easy" }.count
        let medium = bank.questions.filter { $0.difficulty == "medium" }.count
        #expect(easy >= 600, "\(easy) easy")
        #expect(medium >= 1_000, "\(medium) medium")
    }

    @Test func mergedBankDealsFullRoundsInEveryCategory() throws {
        let bank = QuestionBank(merging: [try Self.load("originals"), try Self.load("originals-ai"), try Self.load("opentdb")])
        #expect(bank.dealRound().questions.count == GameRules.questionsPerRound)
        for category in bank.playableCategories {
            let round = bank.dealRound(categories: [category])
            #expect(round.questions.count == GameRules.questionsPerRound, "\(category)")
            #expect(round.reserve.count == GameRules.soloPowerUpsPerRound, "\(category)")
        }
    }
}
