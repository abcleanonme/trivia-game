import Foundation
import Testing
@testable import TriviaKit

private func q(_ n: Int, difficulty: String? = nil, category: String = "Test") -> Question {
    Question(category: category, prompt: "Q\(n)", choices: ["A", "B", "C", "D"], correctIndex: 0,
             difficulty: difficulty)
}

private func game(_ id: String, vs opponent: String = "alex", _ outcome: ChallengeOutcome,
                  mine: Int, theirs: Int, at t: TimeInterval) -> ChallengeGame {
    ChallengeGame(matchID: id, opponentID: opponent, opponentName: opponent.capitalized,
                  outcome: outcome, myPoints: mine, theirPoints: theirs, myCorrect: 5,
                  theirCorrect: 5, questionCount: 10, setup: .standard,
                  playedAt: Date(timeIntervalSince1970: t))
}

@Suite struct ChallengeSetupTests {
    @Test func standardIsTheOldTenQuestionRound() {
        let s = ChallengeSetup.standard
        #expect(s.questionCount == GameRules.questionsPerRound)
        #expect(s.powerUpLimit == GameRules.challengePowerUpsPerRound)
        #expect(s.hasClock)
        #expect(!s.isCustom)
        #expect(s.summary == "10 questions")
    }

    @Test func summaryListsWhatChanged() {
        let s = ChallengeSetup(difficulty: .hard, category: "Science", length: 15,
                               isTimed: false, powerUpLimit: 0)
        #expect(s.summary == "15 questions · Hard · Science · No clock · No power-ups")
        #expect(s.isCustom)
    }

    @Test func speedRoundAlwaysHasItsClock() {
        let s = ChallengeSetup(mode: .speed, isTimed: false).sanitized()
        #expect(s.isTimed)
        #expect(s.hasClock)
        #expect(s.questionCount == ChallengeSetup.longRoundPool)
    }

    @Test func sanitizeClampsBadValues() {
        let s = ChallengeSetup(length: 7, powerUpLimit: 9).sanitized()
        #expect(s.length == GameRules.questionsPerRound)
        #expect(s.powerUpLimit == 3)
    }
}

@Suite struct ChallengeDataSetupTests {
    @Test func classicChallengesStayReadableByOlderBuilds() {
        let d = ChallengeData(setup: ChallengeSetup(difficulty: .hard, length: 5),
                              questions: (0..<5).map { q($0) }, reserve: [])
        #expect(d.version == 1)
        #expect(d.isSupported)
    }

    @Test func survivalAndSpeedNeedTheNewFormat() {
        let d = ChallengeData(setup: ChallengeSetup(mode: .survival), questions: [q(1)], reserve: [])
        #expect(d.version == 2)
        #expect(d.isSupported)
    }

    @Test func setupSurvivesMatchData() throws {
        let setup = ChallengeSetup(mode: .speed, difficulty: .easy, category: "Music",
                                   isTimed: true, powerUpLimit: 1)
        let d = ChallengeData(setup: setup, questions: (0..<40).map { q($0) }, reserve: [q(99)])
        let decoded = try ChallengeData(matchData: d.encoded())
        #expect(decoded.gameMode == .speed)
        #expect(decoded.level == .easy)
        #expect(decoded.setup.category == "Music")
        #expect(decoded.setup.powerUpLimit == 1)
        let s = decoded.makeSession()
        #expect(s.mode == .speed)
        #expect(s.powerUpLimit == 1)
    }

    @Test func oldMatchDataReadsAsClassicMixed() throws {
        let d = ChallengeData(questions: (0..<10).map { q($0) }, reserve: [])
        var json = try JSONSerialization.jsonObject(with: d.encoded()) as! [String: Any]
        json["mode"] = nil
        json["difficulty"] = nil
        let old = try ChallengeData(matchData: JSONSerialization.data(withJSONObject: json))
        #expect(old.gameMode == .classic)
        #expect(old.level == .mixed)
        #expect(old.setup == .standard)
    }

    @Test func untimedClassicRoundHasNoClock() {
        let d = ChallengeData(setup: ChallengeSetup(isTimed: false), questions: [q(1)], reserve: [])
        #expect(!d.makeSession().isTimed)
    }

    @Test func longRoundPoolFitsInMatchData() throws {
        let long = Question(category: "Entertainment: Video Games",
                            prompt: String(repeating: "Which one is right? ", count: 8),
                            choices: (0..<4).map { String(repeating: "Answer \($0) ", count: 4) },
                            correctIndex: 2, difficulty: "hard",
                            source: "Open Trivia Database, CC BY-SA 4.0")
        var d = ChallengeData(setup: ChallengeSetup(mode: .survival, powerUpLimit: 3),
                              questions: Array(repeating: long, count: ChallengeSetup.longRoundPool),
                              reserve: Array(repeating: long, count: 3))
        let answers = Array(repeating: true, count: ChallengeSetup.longRoundPool)
        d.record(ChallengeTurn(playerID: "a", points: 1, correctCount: 1, bestStreak: 1, answers: answers))
        d.record(ChallengeTurn(playerID: "b", points: 2, correctCount: 2, bestStreak: 1, answers: answers))
        #expect(try d.encoded().count < 64 * 1024)
    }

    @Test func bankDealsTheChosenLevel() {
        let bank = QuestionBank(questions: (0..<30).map { q($0, difficulty: $0 < 15 ? "hard" : "easy") })
        let round = bank.dealRound(count: 5, reserve: 1, difficulty: "hard", avoiding: [])
        #expect(round.questions.count == 5)
        #expect(round.questions.allSatisfy { $0.difficulty == "hard" })
    }
}

@Suite struct ChallengeHistoryTests {
    @Test func addsEachMatchOnceNewestFirst() {
        var h = ChallengeHistory()
        #expect(h.add(game("m1", .won, mine: 900, theirs: 700, at: 100)))
        #expect(h.add(game("m2", .lost, mine: 600, theirs: 800, at: 300)))
        #expect(h.add(game("m3", .won, mine: 1_000, theirs: 400, at: 200)))
        #expect(!h.add(game("m1", .won, mine: 900, theirs: 700, at: 100)))
        #expect(h.games.map(\.matchID) == ["m2", "m3", "m1"])
    }

    @Test func statsAgainstOneFriend() {
        var h = ChallengeHistory()
        h.add(game("m1", .won, mine: 900, theirs: 700, at: 100))
        h.add(game("m2", .won, mine: 1_000, theirs: 400, at: 200))
        h.add(game("m3", .lost, mine: 500, theirs: 800, at: 50))
        h.add(game("x", vs: "sam", .lost, mine: 100, theirs: 200, at: 400))
        let s = h.stats(against: "alex")
        #expect(s.played == 3)
        #expect(s.wins == 2 && s.losses == 1 && s.ties == 0)
        #expect(s.averageMine == 800)
        #expect(s.averageTheirs == 633)
        #expect(s.biggestWin == 600)
        #expect(s.bestScore == 1_000)
        #expect(s.run == 2)
        #expect(s.runLabel == "W2")
        #expect(s.lastPlayed == Date(timeIntervalSince1970: 200))
        #expect(h.stats(against: "sam").runLabel == "L1")
        #expect(h.overall.played == 4)
    }

    @Test func aTieEndsTheRun() {
        var h = ChallengeHistory()
        h.add(game("m1", .won, mine: 900, theirs: 700, at: 100))
        h.add(game("m2", .tied, mine: 500, theirs: 500, at: 200))
        #expect(h.stats(against: "alex").run == 0)
        #expect(h.stats(against: "alex").runLabel == nil)
    }

    @Test func opponentsByGamesPlayed() {
        var h = ChallengeHistory()
        h.add(game("a1", vs: "sam", .won, mine: 1, theirs: 0, at: 1))
        h.add(game("b1", vs: "alex", .won, mine: 1, theirs: 0, at: 2))
        h.add(game("b2", vs: "alex", .won, mine: 1, theirs: 0, at: 3))
        #expect(h.opponents.map(\.id) == ["alex", "sam"])
        #expect(h.opponents.first?.games == 2)
    }

    @Test func buildsFromMatchDataOnlyWhenBothPlayed() {
        var d = ChallengeData(setup: ChallengeSetup(difficulty: .medium), questions: [q(1)], reserve: [])
        d.record(ChallengeTurn(playerID: "me", points: 300, correctCount: 1, bestStreak: 1, answers: [true]))
        #expect(ChallengeGame(matchID: "m", data: d, me: "me", opponentID: "alex", opponentName: "Alex",
                              outcome: .won, playedAt: Date()) == nil)
        d.record(ChallengeTurn(playerID: "alex", points: 100, correctCount: 0, bestStreak: 0, answers: [false]))
        let g = ChallengeGame(matchID: "m", data: d, me: "me", opponentID: "alex", opponentName: "Alex",
                              outcome: .won, playedAt: Date())
        #expect(g?.margin == 200)
        #expect(g?.setup.difficulty == .medium)
    }

    @Test func survivesSaving() throws {
        var h = ChallengeHistory()
        h.add(game("m1", .won, mine: 900, theirs: 700, at: 100))
        let decoded = try JSONDecoder().decode(ChallengeHistory.self, from: JSONEncoder().encode(h))
        #expect(decoded == h)
    }
}

@Suite struct FriendBoardTests {
    @Test func idsAreUniqueAndNamespaced() {
        let ids = FriendBoard.allCases.map(\.leaderboardID)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("com.abcapps.trivia.") })
    }

    @Test func relaxedDailiesAreNotPosted() {
        let day = Day(year: 2026, month: 11, day: 14)
        #expect(FriendBoard.dailyScore(DailyRecord(day: day, points: 900, relaxed: true)) == nil)
        #expect(FriendBoard.dailyScore(DailyRecord(day: day, points: 900, relaxed: false)) == 900)
        #expect(FriendBoard.dailyScore(nil) == nil)
    }

    @Test func allTimeValuesComeFromProgress() {
        var p = PlayerProgress()
        p.stats.correctAnswers = 321
        p.stats.bestSurvival = 17
        let today = Day(year: 2026, month: 11, day: 14)
        #expect(FriendBoard.correct.value(progress: p, today: today, challengeWins: 0) == 321)
        #expect(FriendBoard.survival.value(progress: p, today: today, challengeWins: 0) == 17)
        #expect(FriendBoard.challengeWins.value(progress: p, today: today, challengeWins: 4) == 4)
        #expect(FriendBoard.daily.value(progress: p, today: today, challengeWins: 4) == nil)
    }

    @Test func formatsUnits() {
        #expect(FriendBoard.streak.format(1) == "1 day")
        #expect(FriendBoard.challengeWins.format(3) == "3 wins")
        #expect(FriendBoard.daily.format(1_240) == "1,240 pts")
    }
}
