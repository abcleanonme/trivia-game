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
        #expect(p.dailies[day] != nil)
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
        // Weeks before the holiday calendar keep the original rotation.
        let ids = Set((1...10).map { WeeklyEvent.rotationEvent(week: WeeklyEvent.rotationAnchorWeek - $0).id })
        #expect(ids.count == WeeklyEvent.rotation.count)
    }

    @Test func thanksgivingWeekIsTheFeast() {
        #expect(WeeklyEvent.thanksgivingDay(year: 2026) == Day(year: 2026, month: 11, day: 26))
        #expect(WeeklyEvent.thanksgivingDay(year: 2027) == Day(year: 2027, month: 11, day: 25))
        #expect(WeeklyEvent.thanksgivingDay(year: 2029) == Day(year: 2029, month: 11, day: 22))
        for d in 23...29 {
            #expect(WeeklyEvent.event(on: Day(year: 2026, month: 11, day: d)).id == "thanksgiving")
        }
        #expect(WeeklyEvent.event(on: Day(year: 2026, month: 11, day: 22)).id != "thanksgiving")
        #expect(WeeklyEvent.event(on: Day(year: 2026, month: 11, day: 30)).id != "thanksgiving")
    }

    @Test func thanksgivingSkipsCountryAndBands() {
        let e = WeeklyEvent.thanksgiving
        func q(_ p: String) -> Question { Question(category: "General", prompt: p, choices: ["a", "b"], correctIndex: 0) }
        #expect(!e.matches(q("What is the name of the capital of Turkey?")))
        #expect(!e.matches(q("What event inspired The Cranberries song \"Zombie\"?")))
        #expect(!e.matches(q("Who is the lead singer of the Smashing Pumpkins?")))
        #expect(!e.matches(q("Who directed \"Scott Pilgrim vs. the World\"?")))
        #expect(e.matches(q("What is a baby turkey called?")))
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

    @Test func speedMissCostsTimeAndLocksAnswers() {
        var s = GameSession(questions: (0..<50).map { question($0) }, mode: .speed)
        s.answer(1) // wrong
        #expect(s.roundTimeRemaining == GameMode.speedRoundSeconds - GameMode.speedMissPenaltySeconds)
        #expect(s.isLockedOut)
        #expect(s.lockedMiss?.choice == 1)
        #expect(s.index == 0) // the miss stays up during the lockout
        // Spamming during the lockout does nothing.
        s.answer(0)
        s.answer(2)
        #expect(s.results.count == 1)
        #expect(!s.canUse(.skip))
        s.tick(by: 1)
        #expect(s.isLockedOut)
        s.tick(by: 0.5)
        #expect(!s.isLockedOut)
        #expect(s.lockedMiss == nil)
        #expect(s.index == 1)
        #expect(s.phase == .asking)
        // The round clock kept running through the lockout.
        #expect(s.roundTimeRemaining == GameMode.speedRoundSeconds - GameMode.speedMissPenaltySeconds - 1.5)
        s.answer(0)
        #expect(s.correctCount == 1)
        #expect(s.index == 2)
    }

    @Test func speedRoundEndsOnThirdMiss() {
        var s = GameSession(questions: (0..<50).map { question($0) }, mode: .speed)
        for _ in 0..<2 {
            s.answer(1)
            s.tick(by: GameMode.speedMissLockoutSeconds)
        }
        #expect(s.strikesLeft == 1)
        #expect(s.phase == .asking)
        s.answer(1)
        #expect(s.phase == .finished)
        #expect(s.results.count == 3)
    }

    @Test func speedMissPenaltyCanEndTheRound() {
        var s = GameSession(questions: (0..<50).map { question($0) }, mode: .speed)
        s.tick(by: GameMode.speedRoundSeconds - 3)
        s.answer(1)
        #expect(s.roundTimeRemaining == 0)
        #expect(s.phase == .finished)
        #expect(!s.isLockedOut)
    }

    @Test func speedRoundClockRunningOutEndsLockout() {
        var s = GameSession(questions: (0..<50).map { question($0) }, mode: .speed)
        s.tick(by: GameMode.speedRoundSeconds - 6)
        s.answer(1) // 1s left, locked
        s.tick(by: 1)
        #expect(s.phase == .finished)
        #expect(s.lockedMiss == nil)
    }

    @Test func speedStreakPaysTriple() {
        #expect(Scoring.multiplier(forStreak: 10, mode: .speed) == 3)
        #expect(Scoring.multiplier(forStreak: 9, mode: .speed) == 2)
        #expect(Scoring.multiplier(forStreak: 10) == 2) // Classic stays at x2
        var s = GameSession(questions: (0..<50).map { question($0) }, mode: .speed)
        for _ in 0..<10 { s.answer(0) }
        #expect(s.results.last?.points == 300)
        #expect(s.results.first?.points == 100)
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
        var rng = SplitMix64(seed: 7)
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

    @Test func themesArePricedAndAnimated() {
        let themes = CosmeticCatalog.items(in: .theme)
        #expect(themes.count >= 15)
        // Every animation style is used by at least one theme.
        #expect(Set(themes.compactMap(\.motion)) == Set(Cosmetic.Motion.allCases))
        #expect(themes.allSatisfy { $0.motion != nil })
        for theme in themes where theme.unlock != .starter {
            #expect((300...600).contains(theme.price ?? 0))
        }
    }

    @Test func styleShopHasLotsInEverySlot() {
        let minimums: [CosmeticSlot: Int] = [
            .theme: 25, .sounds: 12, .avatar: 40, .border: 25, .cardShape: 9, .cardBackground: 35,
            .emblem: 30, .avatarColor: 20, .nameStyle: 10, .sticker: 28, .finish: 12,
        ]
        for slot in CosmeticSlot.allCases {
            #expect(CosmeticCatalog.items(in: slot).count >= minimums[slot] ?? 1, "\(slot)")
        }
    }

    @Test func cardItemsStayInPriceRange() {
        let card: [CosmeticSlot] = [.avatar, .border, .cardShape, .cardBackground, .emblem,
                                    .avatarColor, .nameStyle, .sticker, .finish]
        for slot in card {
            for item in CosmeticCatalog.items(in: slot) where item.price != nil {
                #expect((60...600).contains(item.price!), "\(item.id)")
            }
        }
    }

    @Test func everyCardStyleIsSold() {
        let all = CosmeticCatalog.all
        let patterns: [Cosmetic.Pattern] = [.solid, .stripes, .dots, .grid, .gradient, .checker, .zigzag,
                                            .waves, .plaid, .stars, .hearts, .argyle, .sprinkles]
        let shapes: [Cosmetic.Shape] = [.rounded, .ticket, .hexagon, .ribbon, .pill, .tag, .stamp, .slant, .scoop]
        let letterings: [Cosmetic.Lettering] = [.classic, .rounded, .serif, .typewriter, .wide, .tall,
                                                .sporty, .newsprint, .arcade, .whisper]
        let finishes: [Cosmetic.Finish] = [Cosmetic.Finish.none, .gloss, .shine, .holo, .sparkle, .prism, .frost, .aurora]
        for p in patterns { #expect(all.contains { $0.slot == .cardBackground && $0.pattern == p }, "\(p)") }
        for s in shapes { #expect(all.contains { $0.shape == s }, "\(s)") }
        for l in letterings { #expect(all.contains { $0.lettering == l }, "\(l)") }
        for f in finishes { #expect(all.contains { $0.finish == f }, "\(f)") }
    }

    @Test func shopShelvesRunFreeThenCheapestThenEarned() {
        for slot in CosmeticSlot.allCases {
            let items = CosmeticCatalog.items(in: slot)
            #expect(items.count == CosmeticCatalog.all.filter { $0.slot == slot }.count)
            let prices = items.compactMap(\.price)
            #expect(prices == prices.sorted(), "\(slot)")
            if let firstPaid = items.firstIndex(where: { $0.price != nil }) {
                #expect(items[..<firstPaid].allSatisfy { $0.unlock == .starter }, "\(slot)")
            }
            if let lastPaid = items.lastIndex(where: { $0.price != nil }) {
                #expect(items[(lastPaid + 1)...].allSatisfy { $0.price == nil && $0.unlock != .starter }, "\(slot)")
            }
        }
    }

    @Test func buyingAThemeEquipsIt() {
        var wallet = Wallet(sparks: 350)
        var inv = Inventory()
        #expect(inv.equipped(.theme).id == "theme.classic")
        #expect(!inv.buy("theme.sunset", with: &wallet)) // 400, too pricey
        #expect(inv.buy("theme.mint", with: &wallet))
        #expect(wallet.sparks == 50)
        inv.equip("theme.mint")
        #expect(inv.equipped(.theme).id == "theme.mint")
        inv.equip("theme.neon") // not owned
        #expect(inv.equipped(.theme).id == "theme.mint")
    }

    @Test func inventorySavedBeforeThemesStillWorks() throws {
        // An inventory saved by a build that had no theme slot.
        let json = #"{"owned":["avatar.monogram","border.ink"],"equipped":{"avatar":"avatar.monogram"}}"#
        let inv = try JSONDecoder().decode(Inventory.self, from: Data(json.utf8))
        #expect(inv.equipped(.theme).id == "theme.classic")
        #expect(inv.owns("theme.classic"))
        #expect(!inv.owns("theme.mint"))
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
        let first = p.recordMatch(.won, against: "g:1", name: "Sam")
        #expect(first == [.firstRivalWin])
        p.recordMatch(.lost, against: "g:1", name: "Sam")
        p.recordMatch(.tied, against: "g:1", name: "Sam")
        #expect(p.rivals.record(for: "g:1")?.summary == "1–1–1")
        var stamps: [Stamp] = []
        for _ in 0..<9 { stamps += p.recordMatch(.won, against: "g:1", name: "Sam") ?? [] }
        #expect(stamps == [.bigRivalry])
    }

    @Test func countsEachMatchOnce() {
        var p = PlayerProgress()
        #expect(p.recordMatch(.won, against: "alex", name: "Alex", matchID: "m1") == [.firstRivalWin])
        #expect(p.recordMatch(.won, against: "alex", name: "Alex", matchID: "m1") == nil)
        #expect(p.rivals.record(for: "alex")?.wins == 1)
        #expect(p.rivals.hasCounted(matchID: "m1"))
        p.rivals.markCounted(["m2"])
        #expect(p.recordMatch(.lost, against: "alex", name: "Alex", matchID: "m2") == nil)
        #expect(p.rivals.record(for: "alex")?.played == 1)
    }

    @Test func keepsLatestNameAndSortsMostRecentFirst() {
        var book = RivalryBook()
        book.add(.won, against: "old", name: "Old", at: Date(timeIntervalSince1970: 100))
        book.add(.lost, against: "new", name: "New", at: Date(timeIntervalSince1970: 200))
        book.add(.tied, against: "new", name: "New G", at: Date(timeIntervalSince1970: 150))
        #expect(book.sorted.map(\.id) == ["new", "old"])
        #expect(book.record(for: "new")?.name == "New G")
        #expect(book.record(for: "new")?.lastPlayed == Date(timeIntervalSince1970: 200))
    }

    @Test func survivesSavingAndReadsOlderSaves() throws {
        var book = RivalryBook()
        book.add(.won, against: "alex", name: "Alex", matchID: "m1")
        var decoded = try JSONDecoder().decode(RivalryBook.self, from: JSONEncoder().encode(book))
        #expect(decoded == book)
        #expect(decoded.add(.won, against: "alex", name: "Alex", matchID: "m1") == nil)
        // Saves from before match IDs were tracked here.
        let old = Data(#"{"records":{"sam":{"id":"sam","name":"Sam","wins":2,"losses":1,"ties":0}}}"#.utf8)
        #expect(try JSONDecoder().decode(RivalryBook.self, from: old).record(for: "sam")?.summary == "2–1")
    }
}

@Suite struct BundledEventTests {
    /// The same files the app loads, events first as in `PlayerStore.eventPool`.
    static let bank = QuestionBank(merging: [try! BundledBankTests.load("events"),
                                             try! BundledBankTests.load("originals"),
                                             try! BundledBankTests.load("originals-ai"),
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
        var rng = SplitMix64(seed: 1)
        let round = Self.bank.dealRound(difficulty: difficulty.tag, using: &rng)
        #expect(round.questions.count == 10)
        if let tag = difficulty.tag { #expect(round.questions.allSatisfy { $0.difficulty == tag }) }
    }
}
