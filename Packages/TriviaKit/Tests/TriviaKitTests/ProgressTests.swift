import Foundation
import Testing
@testable import TriviaKit

private func question(_ n: Int, category: String = "Science", difficulty: String? = nil) -> Question {
    Question(category: category, prompt: "Prompt \(n)", choices: ["A", "B", "C", "D"],
             correctIndex: 0, difficulty: difficulty)
}

/// Plays a session, answering right where `pattern` is true.
private func play(_ session: inout GameSession, _ pattern: [Bool]) {
    for right in pattern {
        guard session.phase == .asking else { break }
        session.answer(right ? 0 : 1)
        session.advance()
    }
}

private func finishedRound(correct: Int, of total: Int = 10, category: String = "Science") -> GameSession {
    var s = GameSession(questions: (0..<total).map { question($0, category: category) })
    play(&s, (0..<total).map { $0 < correct })
    return s
}

@Suite struct DayTests {
    @Test func localDateNotUTCInstant() {
        // 11 pm in Los Angeles on Nov 11 is already Nov 12 in UTC.
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let date = ISO8601DateFormatter().date(from: "2026-11-12T07:00:00Z")!
        #expect(Day(date, timeZone: la) == Day(year: 2026, month: 11, day: 11))
        #expect(Day(year: 2026, month: 11, day: 11).dailyNumber == 1)
    }

    @Test func weeksStartMonday() {
        let wednesday = Day(year: 2026, month: 11, day: 11)
        #expect(wednesday.weekStart == Day(year: 2026, month: 11, day: 9))
        #expect((wednesday + 4).weekIndex == wednesday.weekIndex) // Sunday
        #expect((wednesday + 5).weekIndex == wednesday.weekIndex + 1) // Monday
    }
}

@Suite struct DailyTests {
    static let bank = QuestionBank(questions: (0..<200).map {
        question($0, category: ["Science", "History", "Music", "Art"][$0 % 4])
    })

    @Test func sameQuestionsForEveryoneOnADay() {
        let day = Day(year: 2026, month: 12, day: 1)
        let a = DailyChallenge.round(for: day, from: Self.bank)
        // Another phone loads the bank in a different order with new ids.
        let reloaded = QuestionBank(questions: Self.bank.questions.reversed().map {
            Question(category: $0.category, prompt: $0.prompt, choices: $0.choices, correctIndex: $0.correctIndex)
        })
        let b = DailyChallenge.round(for: day, from: reloaded)
        #expect(a.questions.count == 10)
        #expect(a.questions.map(\.prompt) == b.questions.map(\.prompt))
        #expect(a.questions.map(\.choices) == b.questions.map(\.choices))
        let next = DailyChallenge.round(for: day + 1, from: Self.bank)
        #expect(next.questions.map(\.prompt) != a.questions.map(\.prompt))
    }

    @Test func oneAttemptPerDay() {
        var p = PlayerProgress()
        let day = Day(year: 2026, month: 12, day: 1)
        let first = p.beginDaily(on: day, relaxed: false)
        let second = p.beginDaily(on: day, relaxed: false)
        #expect(first)
        #expect(!second)
    }

    @Test func bonusAndShareCard() {
        var p = PlayerProgress()
        let day = Day(year: 2026, month: 12, day: 1)
        _ = p.beginDaily(on: day, relaxed: false)
        let rewards = p.record(finishedRound(correct: 10), kind: .daily(day))
        #expect(rewards.dailyBonus == DailyChallenge.perfectBonus)
        let record = try! #require(rewards.daily)
        #expect(record.finished)
        #expect(record.correct == 10)
        #expect(record.shareText.contains("Quizio Daily #\(day.dailyNumber)"))
        #expect(record.shareText.contains("10/10"))
        // Spoiler-free: no question text in what gets shared.
        #expect(!record.shareText.contains("Prompt"))
    }

    @Test func quittingUsesTheAttemptButNotTheStreak() {
        var p = PlayerProgress()
        let day = Day(year: 2026, month: 12, day: 1)
        _ = p.beginDaily(on: day, relaxed: false)
        var s = GameSession(questions: (0..<10).map { question($0) })
        play(&s, [true, true])
        let rewards = p.record(s, kind: .daily(day), finished: false)
        #expect(rewards.dailyBonus == 0)
        #expect(p.streak.count == 0)
        #expect(p.hasPlayedDaily(on: day))
    }

    @Test func fastMarks() {
        var s = GameSession(questions: [question(0), question(1)])
        s.tick(by: 2)
        s.answer(0)
        s.advance()
        s.tick(by: 8)
        s.answer(0)
        #expect(s.results.map { DailyMark($0).fast } == [true, false])
    }
}

@Suite struct StreakTests {
    let start = Day(year: 2026, month: 12, day: 1)

    @Test func consecutiveDaysExtend() {
        var s = DailyStreak()
        s.record(start)
        s.record(start + 1)
        #expect(s.record(start + 1) == .sameDay)
        #expect(s.count == 2)
        #expect(s.current(on: start + 2) == 2)
        #expect(s.current(on: start + 3) == 0)
    }

    @Test func missedDayRestartsWithoutFreeze() {
        var s = DailyStreak()
        s.record(start)
        #expect(s.record(start + 2) == .restarted)
        #expect(s.count == 1)
        #expect(s.best == 1)
    }

    @Test func sevenDaysEarnsAFreezeThatCoversOneMiss() {
        var s = DailyStreak()
        for d in 0..<7 { s.record(start + d) }
        #expect(s.freezes == 1)
        #expect(s.current(on: start + 8) == 7) // missed day 7, still alive
        #expect(s.record(start + 8) == .frozeAndExtended(missed: 1))
        #expect(s.count == 8)
        #expect(s.freezes == 0)
    }

    @Test func freezesDoNotStack() {
        var s = DailyStreak()
        for d in 0..<14 { s.record(start + d) }
        #expect(s.freezes == DailyStreak.maxFreezes)
    }
}

@Suite struct MasteryTests {
    @Test func levels() {
        #expect(Mastery.level(forCorrect: 0) == 0)
        #expect(Mastery.level(forCorrect: 24) == 0)
        #expect(Mastery.level(forCorrect: 25) == 1)
        #expect(Mastery.level(forCorrect: 500) == 5)
        #expect(Mastery.level(forCorrect: 5_000) == 10)
        #expect(Mastery.progress(forCorrect: 50) == 0.5)
        #expect(Mastery.remaining(forCorrect: 70) == 5)
    }

    @Test func levelUpPaysSparksAndBadgeAtFive() {
        var p = PlayerProgress()
        p.masteryCorrect["Science"] = 495
        let rewards = p.record(finishedRound(correct: 6), kind: .solo)
        #expect(rewards.levelUps == [.init(category: "Science", level: 5)])
        #expect(rewards.newStamps.contains(.mastery(category: "Science", level: 5)))
        #expect(p.titles.contains("Science Buff"))
        #expect(rewards.sparks == finishedRound(correct: 6).sparksEarned + Mastery.sparks(forLevel: 5))
    }
}

@Suite struct EventTests {
    @Test func everyWeekHasAnEventAndHalloweenIsSpooky() {
        #expect(WeeklyEvent.event(on: Day(year: 2026, month: 10, day: 29)).id == "spooky")
        let ids = Set((0..<10).map { WeeklyEvent.event(on: Day(year: 2027, month: 1, day: 4) + 7 * $0).id })
        #expect(ids.count == WeeklyEvent.rotation.count)
    }

    @Test func rewardsExistInCatalog() {
        for e in WeeklyEvent.all {
            let item = try! #require(CosmeticCatalog.item(e.rewardID), "\(e.id)")
            #expect(item.unlock == .event(e.id))
        }
    }

    @Test func trackPaysMilestonesThenCosmetic() {
        var p = PlayerProgress()
        let event = WeeklyEvent.rotation[0]
        var unlocked: [Cosmetic] = []
        var sparks = 0
        for _ in 0..<4 {
            let r = p.record(finishedRound(correct: 10), kind: .event(event, week: 3000))
            unlocked += r.unlocked
            sparks += r.eventSparks
        }
        #expect(p.eventProgress(event, week: 3000).completed)
        #expect(sparks == 150)
        #expect(unlocked.map(\.id).contains(event.rewardID))
        #expect(p.inventory.owns(event.rewardID))
        // A later run starts a fresh track.
        #expect(p.eventProgress(event, week: 3010).points == 0)
    }
}

@Suite struct ModeTests {
    @Test func survivalEndsOnThirdMiss() {
        var s = GameSession(questions: (0..<50).map { question($0) }, mode: .survival)
        play(&s, [true, false, true, false, true, true])
        #expect(s.strikesLeft == 1)
        s.answer(1)
        #expect(s.isLastQuestion)
        s.advance()
        #expect(s.phase == .finished)
        #expect(s.results.count == 7)
    }

    @Test func speedRoundRunsOnOneClockWithNoStops() {
        var s = GameSession(questions: (0..<50).map { question($0) }, isTimed: false, mode: .speed)
        #expect(s.isTimed) // relaxed doesn't apply
        s.answer(0)
        #expect(s.phase == .asking) // straight to the next one
        #expect(s.index == 1)
        s.tick(by: 30)
        s.answer(0)
        #expect(s.results.allSatisfy { $0.breakdown.speed == 0 })
        let used = s.use(.extraTime)
        #expect(used)
        #expect(s.roundTimeRemaining == 40)
        s.tick(by: 40)
        #expect(s.phase == .finished)
        #expect(s.results.count == 2)
    }

    @Test func harderQuestionsPayMore() {
        #expect(Scoring.breakdown(timeRemaining: nil, streak: 1, powerUp: nil, difficulty: "easy").total == 100)
        #expect(Scoring.breakdown(timeRemaining: nil, streak: 1, powerUp: nil, difficulty: "medium").total == 125)
        #expect(Scoring.breakdown(timeRemaining: nil, streak: 1, powerUp: nil, difficulty: "hard").total == 150)
    }

    @Test func difficultyFilter() {
        let bank = QuestionBank(questions: (0..<60).map {
            question($0, category: ["Science", "Art", "Music"][$0 % 3], difficulty: $0 % 2 == 0 ? "hard" : "easy")
        })
        var rng = SeededRNG(state: 7)
        let round = bank.dealRound(difficulty: "hard", using: &rng)
        #expect(round.questions.count == 10)
        #expect(round.questions.allSatisfy { $0.difficulty == "hard" })
    }
}

@Suite struct CosmeticTests {
    @Test func catalogIDsUniqueAndDefaultsOwned() {
        #expect(Set(CosmeticCatalog.all.map(\.id)).count == CosmeticCatalog.all.count)
        let inv = Inventory()
        for slot in CosmeticSlot.allCases {
            #expect(inv.owns(inv.equipped(slot).id))
            #expect(!CosmeticCatalog.items(in: slot).isEmpty)
        }
    }

    @Test func buyingSpendsSparksOnce() {
        var wallet = Wallet(sparks: 120)
        var inv = Inventory()
        let bought = inv.buy("avatar.cat", with: &wallet)
        #expect(bought)
        #expect(wallet.sparks == 20)
        let again = inv.buy("avatar.cat", with: &wallet)
        let pricey = inv.buy("avatar.brain", with: &wallet) // too expensive
        let earned = inv.buy("border.laurel", with: &wallet) // earned, not sold
        #expect(!again && !pricey && !earned)
        inv.equip("avatar.cat")
        #expect(inv.equipped(.avatar).id == "avatar.cat")
        inv.equip("avatar.brain") // not owned: ignored
        #expect(inv.equipped(.avatar).id == "avatar.cat")
    }

    @Test func perfectRoundUnlocksLaurel() {
        var p = PlayerProgress()
        let r = p.record(finishedRound(correct: 10), kind: .solo)
        #expect(r.newStamps.contains(.perfectRound))
        #expect(r.unlocked.map(\.id).contains("border.laurel"))
        // Only once.
        let again = p.record(finishedRound(correct: 10), kind: .solo)
        #expect(again.newStamps.isEmpty)
    }

    @Test func cardExtrasAreBuyableAndEquippable() {
        var wallet = Wallet(sparks: 2000)
        var inv = Inventory()
        for id in ["color.coral", "letter.serif", "sticker.heart", "finish.holo", "shape.tag", "bg.zigzag"] {
            #expect(inv.buy(id, with: &wallet), "\(id)")
            inv.equip(id)
            #expect(inv.equipped(CosmeticCatalog.item(id)!.slot).id == id)
        }
        #expect(wallet.sparks == 2000 - 60 - 150 - 100 - 600 - 300 - 300)
    }

    @Test func oldSavesGetNewStarterItemsAndStampRewards() throws {
        // An inventory saved before the card extras existed.
        let old = Data(#"{"owned":["avatar.monogram","border.ink","shape.rounded","bg.paper","emblem.none"],"equipped":{"avatar":"avatar.monogram"}}"#.utf8)
        let inv = try JSONDecoder().decode(Inventory.self, from: old)
        for slot in CosmeticSlot.allCases {
            #expect(inv.owns(inv.equipped(slot).id))
        }
        #expect(inv.owns("avatar.star"))

        // A perfect round earned before "100%" sticker was added.
        var p = PlayerProgress()
        _ = p.record(finishedRound(correct: 10), kind: .solo)
        p.inventory = Inventory()
        let restored = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(p))
        #expect(restored.inventory.owns("sticker.perfect"))
        #expect(restored.inventory.owns("border.laurel"))
    }

    @Test func hiddenShowcaseHasNoValue() {
        var p = PlayerProgress()
        p.card.showcase = .hidden
        #expect(p.showcaseValue(on: Day(year: 2026, month: 12, day: 1)).isEmpty)
    }

    @Test func progressRoundTripsAndToleratesMissingFields() throws {
        var p = PlayerProgress()
        _ = p.beginDaily(on: Day(year: 2026, month: 12, day: 1), relaxed: true)
        _ = p.record(finishedRound(correct: 10), kind: .solo)
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(PlayerProgress.self, from: data) == p)
        let empty = try JSONDecoder().decode(PlayerProgress.self, from: Data("{}".utf8))
        #expect(empty == PlayerProgress())
    }
}

@Suite struct RivalryTests {
    @Test func recordsAndStamps() {
        var p = PlayerProgress()
        let first = p.recordMatch(.win, against: "g:1", name: "Sam")
        #expect(first == [.firstRivalWin])
        _ = p.recordMatch(.loss, against: "g:1", name: "Sam")
        _ = p.recordMatch(.tie, against: "g:1", name: "Sam")
        #expect(p.rivals.record(for: "g:1")?.summary == "1–1–1")
        var stamps: [Stamp] = []
        for _ in 0..<9 { stamps += p.recordMatch(.win, against: "g:1", name: "Sam") }
        #expect(stamps == [.bigRivalry])
    }
}

@Suite struct BundledEventTests {
    static let bank = QuestionBank(merging: [try! BundledBankTests.load("originals"),
                                             try! BundledBankTests.load("opentdb")])

    @Test(arguments: WeeklyEvent.all.map(\.id))
    func everyThemeHasEnoughQuestions(id: String) {
        let event = WeeklyEvent.all.first { $0.id == id }!
        #expect(event.pool(from: Self.bank).questions.count >= WeeklyEvent.minimumPool)
    }

    @Test func dailyDealsTenFromTheRealBank() {
        let round = DailyChallenge.round(for: .launch, from: Self.bank)
        #expect(round.questions.count == 10)
        #expect(Set(round.questions.map(\.category)).count >= 5)
    }

    @Test(arguments: Difficulty.allCases)
    func everyDifficultyDealsAFullRound(difficulty: Difficulty) {
        var rng = SeededRNG(state: 1)
        let round = Self.bank.dealRound(difficulty: difficulty.tag, using: &rng)
        #expect(round.questions.count == 10)
        if let tag = difficulty.tag { #expect(round.questions.allSatisfy { $0.difficulty == tag }) }
    }
}
