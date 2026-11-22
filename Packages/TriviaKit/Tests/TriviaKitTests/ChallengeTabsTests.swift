import Foundation
import Testing
@testable import TriviaKit

private func question(_ n: Int, category: String = "Science", difficulty: String? = nil) -> Question {
    Question(category: category, prompt: "Prompt \(n)", choices: ["A", "B", "C", "D"],
             correctIndex: 0, difficulty: difficulty)
}

private func round(correct: Int, timed: Bool = true) -> GameSession {
    var s = GameSession(questions: (0..<10).map { question($0) }, isTimed: timed)
    for i in 0..<10 {
        guard s.phase == .asking else { break }
        s.answer(i < correct ? 0 : 1)
        s.advance()
    }
    return s
}

/// History, previews and leaderboards behind the Daily and Weekly tabs.
@Suite struct DailyTabTests {
    static let bank = QuestionBank(questions: (0..<200).map {
        question($0, category: ["Science", "History", "Music", "Art"][$0 % 4], difficulty: $0 % 5 == 0 ? "hard" : "easy")
    })

    @Test func previewMatchesTheRoundWithoutQuestions() {
        let day = Day(year: 2026, month: 12, day: 2)
        let preview = DailyChallenge.preview(for: day, from: Self.bank)
        let round = DailyChallenge.round(for: day, from: Self.bank).questions
        #expect(preview.total == round.count)
        #expect(preview.categories.map(\.count).reduce(0, +) == round.count)
        #expect(preview.hardCount == round.filter { $0.difficulty == "hard" }.count)
        // Most first.
        #expect(preview.categories.map(\.count) == preview.categories.map(\.count).sorted(by: >))
        #expect(DailyChallenge.preview(for: day, from: Self.bank) == preview)
    }

    @Test func historyIsPastDaysNewestFirst() {
        var p = PlayerProgress()
        let today = Day(year: 2026, month: 11, day: 20)
        for offset in [3, 1, 0, 2] {
            let day = today + -offset
            _ = p.beginDaily(on: day, relaxed: false)
            _ = p.record(round(correct: 10 - offset), kind: .daily(day))
        }
        let history = p.dailyHistory(before: today)
        #expect(history.map(\.day) == [today + -1, today + -2, today + -3])
    }

    @Test func calendarStatuses() {
        var p = PlayerProgress()
        let today = Day(year: 2026, month: 11, day: 20)
        _ = p.beginDaily(on: today + -1, relaxed: false)
        _ = p.record(round(correct: 10), kind: .daily(today + -1))
        _ = p.beginDaily(on: today + -2, relaxed: false)
        _ = p.record(round(correct: 6), kind: .daily(today + -2))
        _ = p.beginDaily(on: today + -3, relaxed: false)
        _ = p.record(round(correct: 2), kind: .daily(today + -3), finished: false)
        #expect(p.dailyStatus(on: today + -1, today: today) == .perfect)
        #expect(p.dailyStatus(on: today + -2, today: today) == .played)
        #expect(p.dailyStatus(on: today + -3, today: today) == .leftEarly)
        #expect(p.dailyStatus(on: today + -4, today: today) == .missed)
        #expect(p.dailyStatus(on: today, today: today) == .open)
        #expect(p.dailyStatus(on: today + 1, today: today) == .upcoming)
        #expect(p.dailyStatus(on: Day.launch + -1, today: today) == .beforeLaunch)
    }

    @Test func summaryCountsFinishedDailiesOnly() {
        var p = PlayerProgress()
        #expect(p.dailySummary.averageCorrect == nil)
        let today = Day(year: 2026, month: 11, day: 20)
        _ = p.beginDaily(on: today, relaxed: false)
        _ = p.record(round(correct: 10), kind: .daily(today))
        _ = p.beginDaily(on: today + -1, relaxed: true)
        _ = p.record(round(correct: 6, timed: false), kind: .daily(today + -1))
        _ = p.beginDaily(on: today + -2, relaxed: false)
        _ = p.record(round(correct: 1), kind: .daily(today + -2), finished: false)
        let s = p.dailySummary
        #expect(s.played == 2)
        #expect(s.perfect == 1)
        #expect(s.averageCorrect == 8)
        #expect(s.bestPoints == p.dailies[today]?.points)
    }

    @Test func boardPeriods() {
        let today = Day(year: 2026, month: 11, day: 20)
        #expect(FriendBoard.daily.context(today: today) == today.ordinal)
        #expect(FriendBoard.daily.context(today: today, previous: true) == today.ordinal - 1)
        #expect(FriendBoard.weekly.context(today: today) == today.weekIndex)
        #expect(FriendBoard.weekly.context(today: today, previous: true) == today.weekIndex - 1)
        #expect(FriendBoard.streak.context(today: today) == nil)
        #expect(FriendBoard.lifetime.allSatisfy { !$0.isRecurring })
        #expect(!FriendBoard.lifetime.contains(.daily) && !FriendBoard.lifetime.contains(.weekly))
        #expect(FriendBoard.weekly.value(progress: PlayerProgress(), today: today) == nil)
    }
}

@Suite struct WeeklyTabTests {
    @Test func bestRoundCountsTimedRoundsOnly() {
        var p = PlayerProgress()
        let event = WeeklyEvent.rotation[1]
        let week = 3000
        _ = p.record(round(correct: 4), kind: .event(event, week: week))
        let timedBest = p.eventProgress(event, week: week).bestRound
        #expect(timedBest > 0)
        #expect(FriendBoard.weeklyScore(p.eventProgress(event, week: week)) == timedBest)
        _ = p.record(round(correct: 10, timed: false), kind: .event(event, week: week))
        let after = p.eventProgress(event, week: week)
        #expect(after.bestRound == timedBest)
        #expect(after.rounds == 2)
        #expect(FriendBoard.weeklyScore(EventProgress()) == nil)
    }

    @Test func oldSavesDecodeWithoutBestRound() throws {
        let json = #"{"points":1200,"rounds":2,"milestonesPaid":1,"completed":false}"#
        let decoded = try JSONDecoder().decode(EventProgress.self, from: Data(json.utf8))
        #expect(decoded.points == 1200 && decoded.rounds == 2 && decoded.bestRound == 0)
        var p = EventProgress()
        _ = p.add(points: 800)
        #expect(try JSONDecoder().decode(EventProgress.self, from: JSONEncoder().encode(p)) == p)
    }

    @Test func historyListsPastWeeksPlayed() {
        var p = PlayerProgress()
        let thisWeek = Day(year: 2026, month: 11, day: 20).weekIndex
        for back in [2, 1, 0] {
            let week = thisWeek - back
            _ = p.record(round(correct: 5), kind: .event(WeeklyEvent.event(week: week), week: week))
        }
        p.events["retired@\(thisWeek - 3)"] = EventProgress()
        let history = p.eventHistory(before: thisWeek)
        #expect(history.map(\.week) == [thisWeek - 1, thisWeek - 2])
        #expect(history[0].event == WeeklyEvent.event(week: thisWeek - 1))
        #expect(history[0].start.weekIndex == thisWeek - 1)
        #expect(history[0].end == history[0].start + 6)
    }

    @Test func upcomingFollowsTheSchedule() {
        let today = Day(year: 2026, month: 11, day: 20)
        let next = WeeklyEvent.upcoming(after: today, count: 3)
        #expect(next.map(\.week) == [today.weekIndex + 1, today.weekIndex + 2, today.weekIndex + 3])
        #expect(next[0].event == WeeklyEvent.event(on: today.weekStart + 7))
        #expect(next[0].start == today.weekStart + 7)
        // Thanksgiving week 2026 is Nov 23-29, so it's next after Nov 20.
        #expect(next[0].event.id == "thanksgiving")
    }

    @Test func instanceIDsRoundTrip() {
        for e in WeeklyEvent.all {
            let parsed = WeeklyEvent.parseInstanceID(WeeklyEvent.instanceID(e, week: 2950))
            #expect(parsed?.event == e && parsed?.week == 2950)
        }
        #expect(WeeklyEvent.parseInstanceID("nope") == nil)
    }
}
