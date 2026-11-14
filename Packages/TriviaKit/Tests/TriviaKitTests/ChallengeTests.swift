import Foundation
import Testing
@testable import TriviaKit

private func q(_ n: Int) -> Question {
    Question(category: "Test", prompt: "Q\(n)", choices: ["A", "B", "C", "D"], correctIndex: 0)
}

private func turn(_ id: String, points: Int, correct: Int = 5) -> ChallengeTurn {
    ChallengeTurn(playerID: id, points: points, correctCount: correct, bestStreak: 2,
                  answers: Array(repeating: true, count: correct),
                  // Whole seconds: match data stores dates as seconds, so a
                  // fractional Date() wouldn't compare equal after decoding.
                  playedAt: Date(timeIntervalSince1970: 1_800_000_000))
}

@Suite struct ChallengeDataTests {
    let data = ChallengeData(questions: (0..<10).map(q), reserve: [q(10), q(11)])

    @Test func roundTripsThroughMatchData() throws {
        var d = data
        d.record(turn("me", points: 900))
        let decoded = try ChallengeData(matchData: try d.encoded())
        #expect(decoded == d)
        #expect(decoded.isSupported)
    }

    @Test func fitsInGameCenterMatchData() throws {
        // GKTurnBasedMatch.matchDataMaximumSize is 64 KB. Long real questions
        // are a few hundred bytes each, so even 3x these stay far below it.
        let long = Question(category: "Entertainment: Video Games",
                            prompt: String(repeating: "Which one is right? ", count: 15),
                            choices: (0..<4).map { String(repeating: "Answer \($0) ", count: 8) },
                            correctIndex: 2, difficulty: "hard",
                            source: "Open Trivia Database, CC BY-SA 4.0")
        var d = ChallengeData(questions: Array(repeating: long, count: 10),
                              reserve: Array(repeating: long, count: 2))
        d.record(turn("a", points: 1))
        d.record(turn("b", points: 2))
        #expect(try d.encoded().count < 64 * 1024 / 3)
    }

    @Test func sessionUsesSharedQuestionsAndChallengeLimit() {
        let s = data.makeSession()
        #expect(s.questions == data.questions)
        #expect(s.reserve == data.reserve)
        #expect(s.powerUpLimit == GameRules.challengePowerUpsPerRound)
        #expect(s.isTimed)
    }

    @Test func aPlayerCanOnlyRecordOnce() {
        var d = data
        let first = d.record(turn("me", points: 500))
        #expect(first)
        let again = d.record(turn("me", points: 9_999))
        #expect(!again)
        #expect(d.turn(for: "me")?.points == 500)
    }

    @Test func finalResultsRankThoseWhoPlayed() {
        var d = data
        d.record(turn("a", points: 900))
        d.record(turn("b", points: 700))
        let r = d.finalResults(for: ["a", "b"])
        #expect(r["a"] == .won)
        #expect(r["b"] == .lost)
        #expect(d.isContested(between: "a", and: "b"))
    }

    @Test func finalResultsWhenFriendNeverPlayed() {
        // Declined or timed out: the challenger wins the match, but it
        // isn't contested, so it stays out of head-to-head records.
        var d = data
        d.record(turn("a", points: 400))
        let r = d.finalResults(for: ["a", "b"])
        #expect(r["a"] == .won)
        #expect(r["b"] == .didNotPlay)
        #expect(!d.isContested(between: "a", and: "b"))
    }

    @Test func finalResultsTieOnEqualScores() {
        var d = data
        d.record(turn("a", points: 500, correct: 5))
        d.record(turn("b", points: 500, correct: 5))
        #expect(d.finalResults(for: ["a", "b"]) == ["a": .tied, "b": .tied])
    }

    @Test func scoreToBeatIgnoresYourOwnTurn() {
        var d = data
        #expect(d.scoreToBeat(for: "friend") == nil)
        d.record(turn("me", points: 1_240))
        #expect(d.scoreToBeat(for: "friend") == 1_240)
        #expect(d.scoreToBeat(for: "me") == nil)
    }

    @Test func noOutcomeUntilEveryonePlayed() {
        var d = data
        d.record(turn("me", points: 800))
        #expect(d.outcome(for: "me", among: ["me", "friend"]) == nil)
    }

    @Test func higherPointsWin() {
        var d = data
        d.record(turn("me", points: 800))
        d.record(turn("friend", points: 700))
        #expect(d.outcome(for: "me", among: ["me", "friend"]) == .won)
        #expect(d.outcome(for: "friend", among: ["me", "friend"]) == .lost)
    }

    @Test func equalPointsBreakOnCorrectAnswers() {
        var d = data
        d.record(turn("me", points: 800, correct: 6))
        d.record(turn("friend", points: 800, correct: 5))
        #expect(d.outcome(for: "me", among: ["me", "friend"]) == .won)
    }

    @Test func fullyEqualIsATie() {
        var d = data
        d.record(turn("me", points: 800))
        d.record(turn("friend", points: 800))
        #expect(d.outcome(for: "me", among: ["me", "friend"]) == .tied)
        #expect(d.outcome(for: "friend", among: ["me", "friend"]) == .tied)
    }

    @Test func turnFromAnAbandonedSessionCountsUnplayedAsWrong() {
        var s = data.makeSession()
        s.answer(0)
        s.advance()
        s.answer(1)
        let t = ChallengeTurn(playerID: "me", session: s)
        #expect(t.answers.count == 10)
        #expect(t.answers.prefix(2) == [true, false])
        #expect(t.answers.dropFirst(2).allSatisfy { !$0 })
        #expect(t.correctCount == 1)
        #expect(t.points == s.totalPoints)
    }

    @Test func newerFormatIsFlaggedUnsupported() throws {
        var json = try JSONSerialization.jsonObject(with: try data.encoded()) as! [String: Any]
        json["version"] = ChallengeData.currentVersion + 1
        let d = try ChallengeData(matchData: try JSONSerialization.data(withJSONObject: json))
        #expect(!d.isSupported)
    }
}

@Suite struct ChallengeRivalryBookTests {
    @Test func countsEachMatchOnce() {
        var book = ChallengeRivalryBook()
        let first = book.add(.won, matchID: "m1", opponentID: "alex", opponentName: "Alex")
        #expect(first)
        let again = book.add(.won, matchID: "m1", opponentID: "alex", opponentName: "Alex")
        #expect(!again)
        #expect(book.record(against: "alex")?.wins == 1)
        #expect(book.hasCounted(matchID: "m1"))
    }

    @Test func keepsARunningRecord() {
        var book = ChallengeRivalryBook()
        book.add(.won, matchID: "m1", opponentID: "alex", opponentName: "Alex")
        book.add(.won, matchID: "m2", opponentID: "alex", opponentName: "Alex")
        book.add(.lost, matchID: "m3", opponentID: "alex", opponentName: "Alex G")
        let r = book.record(against: "alex")
        #expect(r?.summary == "2–1")
        #expect(r?.played == 3)
        #expect(r?.displayName == "Alex G")
        book.add(.tied, matchID: "m4", opponentID: "alex", opponentName: "Alex G")
        #expect(book.record(against: "alex")?.summary == "2–1–1")
    }

    @Test func rivalsSortMostRecentFirst() {
        var book = ChallengeRivalryBook()
        book.add(.won, matchID: "m1", opponentID: "old", opponentName: "Old",
                 playedAt: Date(timeIntervalSince1970: 100))
        book.add(.lost, matchID: "m2", opponentID: "new", opponentName: "New",
                 playedAt: Date(timeIntervalSince1970: 200))
        #expect(book.rivals.map(\.id) == ["new", "old"])
    }

    @Test func survivesSaving() throws {
        var book = ChallengeRivalryBook()
        book.add(.won, matchID: "m1", opponentID: "alex", opponentName: "Alex")
        let decoded = try JSONDecoder().decode(ChallengeRivalryBook.self, from: JSONEncoder().encode(book))
        #expect(decoded == book)
        var copy = decoded
        let added = copy.add(.won, matchID: "m1", opponentID: "alex", opponentName: "Alex")
        #expect(!added)
    }
}
