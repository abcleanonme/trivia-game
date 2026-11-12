import Foundation
import Testing
@testable import TriviaKit

/// Deterministic RNG so power-up and dealing tests are repeatable.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func q(_ n: Int, correct: Int = 0) -> Question {
    Question(category: "Test", prompt: "Q\(n)", choices: ["A", "B", "C", "D"], correctIndex: correct)
}

private func makeQuestions(_ count: Int) -> [Question] { (0..<count).map { q($0) } }

@Suite struct ScoringTests {
    @Test func instantAnswerGetsFullSpeedBonus() {
        let b = Scoring.breakdown(timeRemaining: 20, streak: 1, powerUp: nil)
        #expect(b == ScoreBreakdown(base: 100, speed: 50, streakBonus: 0))
        #expect(b.total == 150)
    }

    @Test func speedBonusScalesWithTimeLeft() {
        #expect(Scoring.breakdown(timeRemaining: 10, streak: 1, powerUp: nil).speed == 25)
        #expect(Scoring.breakdown(timeRemaining: 0, streak: 1, powerUp: nil).speed == 0)
        // Extra time can push the clock past 20s; the bonus still caps at 50.
        #expect(Scoring.breakdown(timeRemaining: 28, streak: 1, powerUp: nil).speed == 50)
    }

    @Test func relaxedModeHasNoSpeedBonus() {
        #expect(Scoring.breakdown(timeRemaining: nil, streak: 1, powerUp: nil).total == 100)
    }

    @Test func streakMultipliers() {
        #expect(Scoring.multiplier(forStreak: 2) == 1)
        #expect(Scoring.multiplier(forStreak: 3) == 1.5)
        #expect(Scoring.multiplier(forStreak: 4) == 1.5)
        #expect(Scoring.multiplier(forStreak: 5) == 2)
        #expect(Scoring.breakdown(timeRemaining: nil, streak: 3, powerUp: nil).total == 150)
        #expect(Scoring.breakdown(timeRemaining: nil, streak: 5, powerUp: nil).total == 200)
    }

    @Test func powerUpForfeitsSpeedBonus() {
        #expect(Scoring.breakdown(timeRemaining: 20, streak: 1, powerUp: .fiftyFifty).total == 100)
    }

    @Test func doubleDownDoubles() {
        let b = Scoring.breakdown(timeRemaining: 20, streak: 3, powerUp: .doubleDown)
        #expect(b.total == 300) // 100 base, no speed, x1.5 streak, x2
    }

    @Test func secondChanceHalves() {
        #expect(Scoring.breakdown(timeRemaining: 5, streak: 1, powerUp: .secondChance).total == 50)
    }

    @Test func sparksAreOnePerTenPoints() {
        #expect(Scoring.sparks(forPoints: 1_249) == 124)
        #expect(Scoring.sparks(forPoints: 0) == 0)
    }
}

@Suite struct GameSessionTests {
    @Test func correctAnswerScores() {
        var game = GameSession(questions: makeQuestions(3))
        game.answer(0)
        #expect(game.totalPoints == 150)
        #expect(game.streak == 1)
    }

    @Test func wrongAnswerDoesNotScoreAndResetsStreak() {
        var game = GameSession(questions: makeQuestions(3))
        game.answer(0); game.advance()
        game.answer(1)
        #expect(game.totalPoints == 150)
        #expect(game.streak == 0)
        #expect(game.bestStreak == 1)
    }

    @Test func clockRunningOutIsAMiss() {
        var game = GameSession(questions: makeQuestions(2))
        game.tick(by: 19.9)
        #expect(game.phase == .asking)
        game.tick(by: 0.2)
        guard case .answered(let r) = game.phase else { Issue.record("expected answered"); return }
        #expect(r.timedOut)
        #expect(!r.correct)
    }

    @Test func relaxedModeClockNeverMoves() {
        var game = GameSession(questions: makeQuestions(1), isTimed: false)
        game.tick(by: 100)
        #expect(game.phase == .asking)
        game.answer(0)
        #expect(game.totalPoints == 100)
    }

    @Test func finishesAfterLastQuestion() {
        var game = GameSession(questions: makeQuestions(3))
        for _ in 0..<3 {
            game.answer(0)
            game.advance()
        }
        #expect(game.phase == .finished)
        #expect(game.correctCount == 3)
        #expect(game.currentQuestion == nil)
    }

    @Test func cannotAnswerTwice() {
        var game = GameSession(questions: makeQuestions(2))
        game.answer(0)
        game.answer(0)
        #expect(game.results.count == 1)
    }

    @Test func emptyGameIsFinished() {
        #expect(GameSession(questions: []).phase == .finished)
    }

    @Test func streakBonusKicksInAtThree() {
        var game = GameSession(questions: makeQuestions(5), isTimed: false)
        for _ in 0..<5 { game.answer(0); game.advance() }
        // 100, 100, 150, 150, 200
        #expect(game.totalPoints == 700)
        #expect(game.breakdown.streakBonus == 200)
    }
}

@Suite struct PowerUpTests {
    @Test func onlyOnePowerUpPerQuestion() {
        var game = GameSession(questions: makeQuestions(2))
        do { let ok = game.use(.extraTime); #expect(ok) }
        do { let ok = game.use(.doubleDown); #expect(!ok) }
        #expect(game.timeRemaining == 30)
    }

    @Test func roundLimitIsThree() {
        var game = GameSession(questions: makeQuestions(5), isTimed: false)
        for _ in 0..<3 {
            do { let ok = game.use(.doubleDown); #expect(ok) }
            game.answer(0); game.advance()
        }
        #expect(!game.canUse(.doubleDown))
    }

    @Test func fiftyFiftyRemovesTwoWrongAnswers() {
        var rng = SeededRNG(state: 42)
        var game = GameSession(questions: makeQuestions(1))
        do { let ok = game.use(.fiftyFifty, using: &rng); #expect(ok) }
        #expect(game.eliminated.count == 2)
        #expect(!game.eliminated.contains(0))
        // Eliminated answers can't be picked.
        game.answer(game.eliminated.first!)
        #expect(game.phase == .asking)
    }

    @Test func skipSwapsQuestionKeepsStreakAndResetsClock() {
        let spare = q(99)
        var game = GameSession(questions: makeQuestions(2), reserve: [spare])
        game.answer(0); game.advance()
        game.tick(by: 8)
        do { let ok = game.use(.skip); #expect(ok) }
        #expect(game.currentQuestion == spare)
        #expect(game.streak == 1)
        #expect(game.timeRemaining == GameRules.questionTime)
        #expect(game.questions.count == 2)
        #expect(!game.canUse(.skip)) // reserve now empty
        #expect(game.canUse(.extraTime)) // fresh question, fresh slot
    }

    @Test func secondChanceRetriesForHalfPointsAndKeepsStreak() {
        var game = GameSession(questions: makeQuestions(3))
        game.answer(0); game.advance()
        game.answer(0); game.advance()
        #expect(game.streak == 2)
        game.answer(2) // miss
        #expect(game.streak == 0)
        #expect(game.canUse(.secondChance))
        do { let ok = game.use(.secondChance); #expect(ok) }
        #expect(game.phase == .asking)
        #expect(game.eliminated == [2])
        #expect(game.streak == 2)
        game.answer(0)
        // streak 3 => x1.5 on 100 (no speed), then halved
        #expect(game.results.last?.points == 75)
        #expect(game.results.count == 3)
    }

    @Test func secondChanceNotOfferedAfterTimeout() {
        var game = GameSession(questions: makeQuestions(1))
        game.tick(by: 30)
        #expect(!game.canUse(.secondChance))
    }

    @Test func secondChanceNotOfferedAfterAnotherPowerUp() {
        var game = GameSession(questions: makeQuestions(1))
        game.use(.doubleDown)
        game.answer(1)
        #expect(!game.canUse(.secondChance))
        #expect(game.streak == 0)
    }

    @Test func doubleDownMissScoresNothing() {
        var game = GameSession(questions: makeQuestions(1))
        game.use(.doubleDown)
        game.answer(3)
        #expect(game.totalPoints == 0)
    }
}

@Suite struct WalletTests {
    @Test func buyAndConsume() {
        var wallet = Wallet(sparks: 50)
        do { let ok = wallet.buy(.fiftyFifty); #expect(ok) }
        #expect(wallet.sparks == 20)
        do { let ok = wallet.buy(.fiftyFifty); #expect(!ok) }
        do { let ok = wallet.consume(.fiftyFifty); #expect(ok) }
        do { let ok = wallet.consume(.fiftyFifty); #expect(!ok) }
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(Wallet.starter)
        #expect(try JSONDecoder().decode(Wallet.self, from: data) == .starter)
    }
}

@Suite struct QuestionBankTests {
    @Test func dealsDistinctQuestionsAndReserve() {
        var rng = SeededRNG(state: 7)
        let bank = QuestionBank(questions: makeQuestions(20))
        let round = bank.dealRound(count: 10, reserve: 3, using: &rng)
        #expect(round.questions.count == 10)
        #expect(round.reserve.count == 3)
        let ids = Set((round.questions + round.reserve).map(\.id))
        #expect(ids.count == 13)
    }

    @Test func shufflingKeepsTheRightAnswer() {
        var rng = SeededRNG(state: 1)
        let original = Question(category: "T", prompt: "P", choices: ["w", "x", "y", "z"], correctIndex: 2)
        for _ in 0..<10 {
            #expect(original.shufflingChoices(using: &rng).correctAnswer == "y")
        }
    }

    @Test func avoidsRecentlySeenQuestionsWhenPossible() {
        var rng = SeededRNG(state: 3)
        let bank = QuestionBank(questions: makeQuestions(20))
        let recent = Set((0..<10).map { "q\($0)" })
        let round = bank.dealRound(count: 10, reserve: 0, avoiding: recent, using: &rng)
        #expect(round.questions.allSatisfy { !recent.contains($0.prompt.lowercased()) })
        // With too few fresh ones, recent questions fill the gap.
        let big = bank.dealRound(count: 15, reserve: 0, avoiding: recent, using: &rng)
        #expect(big.questions.count == 15)
    }

    @Test func mixedRoundsSpreadAcrossCategories() {
        var rng = SeededRNG(state: 11)
        // 60 "Games" questions and 5 each of six other categories.
        var pool = (0..<60).map { Question(category: "Games", prompt: "g\($0)", choices: ["a", "b"], correctIndex: 0) }
        for c in ["A", "B", "C", "D", "E", "F"] {
            pool += (0..<5).map { Question(category: c, prompt: "\(c)\($0)", choices: ["a", "b"], correctIndex: 0) }
        }
        let round = QuestionBank(questions: pool).dealRound(count: 10, reserve: 0, using: &rng)
        let games = round.questions.filter { $0.category == "Games" }.count
        #expect(round.questions.count == 10)
        #expect(games <= QuestionBank.maxPerCategoryInMix)
    }

    @Test func capsHardQuestions() {
        let pool = (0..<20).map {
            Question(category: "C\($0)", prompt: "p\($0)", choices: ["a", "b"], correctIndex: 0,
                     difficulty: $0 < 15 ? "hard" : "easy")
        }
        let picked = QuestionBank.balanced(pool, take: 10, maxPerCategory: nil)
        #expect(picked.count == 10)
        // 3 hard allowed + 5 easy available = 8, then hard ones fill the gap.
        #expect(picked.prefix(8).filter { $0.difficulty == "hard" }.count == 3)
    }

    @Test func categoryRoundsIgnoreTheCategoryCap() {
        let pool = (0..<12).map { Question(category: "Games", prompt: "g\($0)", choices: ["a", "b"], correctIndex: 0) }
        #expect(QuestionBank(questions: pool).dealRound(count: 10, reserve: 0, category: "Games").questions.count == 10)
    }

    @Test func mergingDropsDuplicatePrompts() {
        let a = QuestionBank(questions: makeQuestions(3))
        let b = QuestionBank(questions: makeQuestions(5))
        #expect(QuestionBank(merging: [a, b]).questions.count == 5)
    }

    @Test func categoriesFollowPreferredOrder() {
        let bank = QuestionBank(questions: ["Zoology", "History", "General"].map {
            Question(category: $0, prompt: $0, choices: ["a", "b"], correctIndex: 0)
        })
        #expect(bank.categories == ["General", "History", "Zoology"])
    }

    @Test func filtersByCategory() {
        let bank = QuestionBank(questions: [
            Question(category: "A", prompt: "1", choices: ["a", "b"], correctIndex: 0),
            Question(category: "B", prompt: "2", choices: ["a", "b"], correctIndex: 0),
        ])
        #expect(bank.dealRound(category: "B").questions.map(\.prompt) == ["2"])
    }

    @Test func decodesJSONWithoutIDs() throws {
        let json = #"[{"category":"A","prompt":"P","choices":["x","y"],"correctIndex":1}]"#
        let bank = try QuestionBank(jsonData: Data(json.utf8))
        #expect(bank.questions.first?.correctAnswer == "y")
    }

    @Test func rejectsOutOfRangeAnswer() {
        let json = #"[{"category":"A","prompt":"P","choices":["x","y"],"correctIndex":5}]"#
        #expect(throws: DecodingError.self) { try QuestionBank(jsonData: Data(json.utf8)) }
    }
}
