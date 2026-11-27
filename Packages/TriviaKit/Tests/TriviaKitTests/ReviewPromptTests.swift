import Testing
@testable import TriviaKit

struct ReviewPromptTests {
    let day1 = Day(year: 2026, month: 12, day: 1)

    @Test func goodMoments() {
        #expect(ReviewPrompt.isGood(.challengeWin(matchID: "m1")))
        #expect(ReviewPrompt.isGood(.round(correct: 8, of: 10)))
        #expect(!ReviewPrompt.isGood(.round(correct: 7, of: 10)))
        #expect(!ReviewPrompt.isGood(.round(correct: 4, of: 4)))
    }

    @Test func neverOnFirstDay() {
        var p = ReviewPrompt()
        for _ in 0..<10 { #expect(!p.shouldAsk(after: .challengeWin(matchID: "m2"), on: day1, version: "1.0.1")) }
    }

    @Test func asksAfterEnoughGoodMomentsOnALaterDay() {
        var p = ReviewPrompt()
        p.notePlayed(on: day1)
        let day2 = Day(ordinal: day1.ordinal + 1)
        #expect(!p.shouldAsk(after: .round(correct: 3, of: 10), on: day2, version: "1.0.1"))
        #expect(!p.shouldAsk(after: .challengeWin(matchID: "m3"), on: day2, version: "1.0.1"))
        #expect(!p.shouldAsk(after: .challengeWin(matchID: "m4"), on: day2, version: "1.0.1"))
        #expect(p.shouldAsk(after: .challengeWin(matchID: "m5"), on: day2, version: "1.0.1"))
        // Asked: nothing more this version or within the cooldown.
        for _ in 0..<5 { #expect(!p.shouldAsk(after: .challengeWin(matchID: "m6"), on: day2, version: "1.0.1")) }
        let soon = Day(ordinal: day2.ordinal + 30)
        for _ in 0..<5 { #expect(!p.shouldAsk(after: .challengeWin(matchID: "m7"), on: soon, version: "1.0.2")) }
        let later = Day(ordinal: day2.ordinal + ReviewPrompt.cooldownDays)
        #expect(p.shouldAsk(after: .challengeWin(matchID: "m8"), on: later, version: "1.1"))
    }

    @Test func reopenedWinCountsOnce() {
        var p = ReviewPrompt()
        p.notePlayed(on: day1)
        let day2 = Day(ordinal: day1.ordinal + 1)
        for _ in 0..<5 { #expect(!p.shouldAsk(after: .challengeWin(matchID: "same"), on: day2, version: "1.0.1")) }
        #expect(p.goodMoments == 1)
    }

    @Test func sameVersionNeverAsksTwice() {
        var p = ReviewPrompt()
        p.notePlayed(on: day1)
        let day2 = Day(ordinal: day1.ordinal + 1)
        for i in 0..<3 { _ = p.shouldAsk(after: .challengeWin(matchID: "v\(i)"), on: day2, version: "1.0.1") }
        #expect(p.lastAsked == day2)
        let much = Day(ordinal: day2.ordinal + 400)
        for _ in 0..<5 { #expect(!p.shouldAsk(after: .challengeWin(matchID: "m10"), on: much, version: "1.0.1")) }
    }
}
