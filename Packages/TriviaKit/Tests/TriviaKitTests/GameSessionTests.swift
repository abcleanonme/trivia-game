import Testing
@testable import TriviaKit

@Suite struct GameSessionTests {
    @Test func correctAnswerScores() {
        var game = GameSession(questions: Question.samples)
        game.answer(Question.samples[0].correctIndex)
        #expect(game.score == 1)
    }

    @Test func wrongAnswerDoesNotScore() {
        var game = GameSession(questions: Question.samples)
        game.answer((Question.samples[0].correctIndex + 1) % 4)
        #expect(game.score == 0)
    }

    @Test func finishesAfterLastQuestion() {
        var game = GameSession(questions: Question.samples)
        for q in Question.samples {
            game.answer(q.correctIndex)
            game.advance()
        }
        #expect(game.state == .finished)
        #expect(game.score == Question.samples.count)
    }

    @Test func cannotAnswerTwice() {
        var game = GameSession(questions: Question.samples)
        game.answer(Question.samples[0].correctIndex)
        game.answer(Question.samples[0].correctIndex)
        #expect(game.score == 1)
    }

    @Test func emptyGameIsFinished() {
        #expect(GameSession(questions: []).state == .finished)
    }
}
