import Foundation
import Testing
@testable import TriviaKit

private func q(_ n: Int) -> Question {
    Question(category: "Test", prompt: "Q\(n)", choices: ["A", "B", "C", "D"], correctIndex: 0)
}

private func pick(_ question: Question, _ choice: Int?, _ seconds: Double) -> ChallengePick {
    ChallengePick(questionID: question.id, choice: choice, seconds: seconds,
                  correct: choice == question.correctIndex, points: choice == question.correctIndex ? 100 : 0)
}

private func turn(_ id: String, points: Int, correct: Int = 3, picks: [ChallengePick]? = nil) -> ChallengeTurn {
    ChallengeTurn(playerID: id, points: points, correctCount: correct, bestStreak: 1,
                  answers: Array(repeating: true, count: correct),
                  playedAt: Date(timeIntervalSince1970: 1_800_000_000), picks: picks)
}

@Suite struct GroupStandingsTests {
    let qs = (0..<3).map(q)

    @Test func placesShareTiesAndSkipNext() {
        var d = ChallengeData(questions: qs, reserve: [])
        d.record(turn("a", points: 900))
        d.record(turn("b", points: 1_200))
        d.record(turn("c", points: 900))
        d.record(turn("d", points: 500))
        let s = d.standings(among: ["a", "b", "c", "d"])
        #expect(s.map(\.playerID).first == "b")
        #expect(s.first { $0.playerID == "a" }?.place == 2)
        #expect(s.first { $0.playerID == "c" }?.place == 2)
        #expect(s.first { $0.playerID == "d" }?.place == 4)
    }

    @Test func groupWinnerIsTheOnlyWinner() {
        var d = ChallengeData(questions: qs, reserve: [])
        for (id, p) in [("a", 700), ("b", 1_000), ("c", 400)] { d.record(turn(id, points: p)) }
        let r = d.finalResults(for: ["a", "b", "c"])
        #expect(r["b"] == .won)
        #expect(r["a"] == .lost)
        #expect(r["c"] == .lost)
    }

    @Test func groupCopyKeepsQuestionsAndScores() throws {
        var d = ChallengeData(setup: ChallengeSetup(mode: .speed, allowsInvites: true),
                              questions: qs, reserve: [q(9)])
        d.record(turn("a", points: 800))
        d.setPlayer(ChallengePlayer(card: SharedCard(name: "Ann", title: "Rookie"), build: 9), for: "a")
        let g = d.groupCopy(from: "old")
        #expect(g.groupFrom == "old")
        #expect(g.questions == d.questions)
        #expect(g.reserve == d.reserve)
        #expect(g.gameMode == .speed)
        #expect(g.hasPlayed("a"))
        #expect(g.player("a")?.card?.name == "Ann")
        let decoded = try ChallengeData(matchData: g.encoded())
        #expect(decoded == g)
    }

    @Test func invitesCanBeTurnedOff() throws {
        let d = ChallengeData(setup: ChallengeSetup(allowsInvites: false), questions: qs, reserve: [])
        #expect(!d.allowsInvites)
        #expect(!d.setup.allowsInvites)
        #expect(try !ChallengeData(matchData: d.encoded()).allowsInvites)
    }

    @Test func oldSavedSetupsStillDecode() throws {
        let json = #"{"mode":"classic","difficulty":"mixed","length":10,"isTimed":true,"powerUpLimit":2}"#
        let s = try JSONDecoder().decode(ChallengeSetup.self, from: Data(json.utf8))
        #expect(s.allowsInvites)
        #expect(s == ChallengeSetup(powerUpLimit: 2))
    }

    @Test func buildsShowWhoIsOutOfDate() {
        var d = ChallengeData(questions: qs, reserve: [])
        d.setPlayer(ChallengePlayer(card: nil, build: 8), for: "me")
        d.setPlayer(ChallengePlayer(card: nil, build: 9), for: "new")
        d.setPlayer(ChallengePlayer(card: nil, build: 7), for: "old")
        #expect(d.playersAhead(of: 8, me: "me") == ["new"])
        #expect(d.playersBehind(8, me: "me") == ["old"])
    }

    @Test func sixPlayersOfLongRoundsFitInMatchData() throws {
        let long = (0..<ChallengeSetup.longRoundPool).map {
            Question(category: "Geography", prompt: String(repeating: "Which capital city is this? ", count: 6) + "\($0)",
                     choices: ["Ouagadougou", "Antananarivo", "Ulaanbaatar", "Kuala Lumpur"], correctIndex: 0)
        }
        var d = ChallengeData(setup: ChallengeSetup(mode: .speed, powerUpLimit: 3), questions: long, reserve: Array(long.prefix(3)))
        for i in 0..<ChallengeData.maxPlayers {
            let picks = long.map { pick($0, 1, 3.3) }
            d.record(turn("player-\(i)-abcdefghijklmnop", points: 1_000, picks: picks))
            d.setPlayer(ChallengePlayer(card: SharedCard(name: "Somebody Long", title: "Trivia Royalty",
                                                         statLabel: "Best streak", statValue: "12", corner: "star.fill",
                                                         items: Dictionary(uniqueKeysWithValues: SharedCard.slots.map { ($0.rawValue, "avatar.monogram") })),
                                        build: 10, version: "0.3.0"),
                        for: "player-\(i)-abcdefghijklmnop")
        }
        #expect(try d.encoded().count < 64_000)
    }
}

@Suite struct ReplayTests {
    let qs = (0..<4).map(q)

    @Test func picksComeFromTheSession() {
        var s = GameSession(questions: Array(qs.prefix(2)), isTimed: false)
        s.tick(by: 2.5)
        s.answer(1)
        s.advance()
        s.tick(by: 4)
        s.answer(0)
        let t = ChallengeTurn(playerID: "me", session: s)
        #expect(t.picks?.count == 2)
        #expect(t.picks?[0].choice == 1)
        #expect(t.picks?[0].seconds == 2.5)
        #expect(t.picks?[0].correct == false)
        #expect(t.picks?[1].seconds == 4)
        #expect(t.picks?[1].correct == true)
    }

    @Test func replayOrdersAnswersFastestFirst() {
        var d = ChallengeData(questions: qs, reserve: [])
        d.record(turn("a", points: 200, picks: [pick(qs[0], 0, 6), pick(qs[1], 2, 3)]))
        d.record(turn("b", points: 100, picks: [pick(qs[0], 1, 2), pick(qs[1], nil, 20)]))
        let r = d.replay(among: ["a", "b"])
        #expect(r.count == 2)
        #expect(r[0].answers.map(\.playerID) == ["b", "a"])
        #expect(r[0].players(choosing: 0) == ["a"])
        #expect(r[1].answer(for: "b")?.pick.timedOut == true)
        #expect(r[0].duration == 6)
    }

    @Test func skipAddsTheSpareAfterTheDealtQuestion() {
        let spare = q(99)
        var d = ChallengeData(questions: qs, reserve: [spare])
        d.record(turn("a", points: 200, picks: [pick(spare, 0, 5), pick(qs[1], 0, 3)]))
        d.record(turn("b", points: 100, picks: [pick(qs[0], 0, 4)]))
        let r = d.replay(among: ["a", "b"])
        #expect(r.map(\.question.id) == [qs[0].id, spare.id, qs[1].id])
        #expect(r[0].skipped == ["a"])
        #expect(r[1].isSpare)
        #expect(r[2].didNotReach == ["b"])
    }

    @Test func oldTurnsHaveNoReplay() throws {
        var d = ChallengeData(questions: qs, reserve: [])
        d.record(turn("a", points: 100))
        #expect(!d.hasReplay)
        #expect(d.replay(among: ["a"]).isEmpty)
    }

    @Test func picksStayCompact() throws {
        let data = try JSONEncoder().encode(pick(qs[0], 2, 3.14159))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"s\":3.1"))
        #expect(!text.contains("questionID"))
    }
}

@Suite struct MatchArchiveTests {
    @Test func keepsNewestFirstAndDedupes() {
        let d = ChallengeData(questions: [q(1)], reserve: [])
        var a = MatchArchive()
        a.add(ArchivedMatch(matchID: "1", data: d, playerIDs: ["a", "b"], names: [:], finishedAt: Date(timeIntervalSince1970: 10)))
        a.add(ArchivedMatch(matchID: "2", data: d, playerIDs: ["a", "b", "c"], names: [:], finishedAt: Date(timeIntervalSince1970: 20)))
        #expect(!a.add(ArchivedMatch(matchID: "1", data: d, playerIDs: ["a", "b"], names: [:], finishedAt: Date(timeIntervalSince1970: 10))))
        #expect(a.matches.map(\.matchID) == ["2", "1"])
        #expect(a.groups.map(\.matchID) == ["2"])
    }

    @Test func sharedCardFallsBackOnUnknownItems() {
        let card = SharedCard(name: "Ann", title: "Rookie", items: ["avatar": "avatar.from-the-future", "border": "avatar.cat"])
        #expect(card.item(.avatar).id == CosmeticCatalog.defaults[.avatar])
        // An ID from the wrong slot doesn't sneak in.
        #expect(card.item(.border).id == CosmeticCatalog.defaults[.border])
    }
}
