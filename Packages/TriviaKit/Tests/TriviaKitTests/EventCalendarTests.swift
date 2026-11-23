import Foundation
import Testing
@testable import TriviaKit

/// The holiday calendar and the rotation around it. See
/// docs/content-updates.md for the schedule these pin down.
@Suite struct EventCalendarTests {
    func id(_ y: Int, _ m: Int, _ d: Int) -> String { WeeklyEvent.event(on: Day(year: y, month: m, day: d)).id }

    @Test func holidayDatesAreRight() {
        #expect(WeeklyEvent.easterSunday(year: 2025) == Day(year: 2025, month: 4, day: 20))
        #expect(WeeklyEvent.easterSunday(year: 2027) == Day(year: 2027, month: 3, day: 28))
        #expect(WeeklyEvent.easterSunday(year: 2028) == Day(year: 2028, month: 4, day: 16))
        // MLK Day: third Monday of January. Big Game: second Sunday of February.
        #expect(WeeklyEvent.nth(3, weekday: 0, month: 1, year: 2027) == Day(year: 2027, month: 1, day: 18))
        #expect(WeeklyEvent.nth(2, weekday: 6, month: 2, year: 2026) == Day(year: 2026, month: 2, day: 8))
        #expect(WeeklyEvent.nth(2, weekday: 6, month: 2, year: 2027) == Day(year: 2027, month: 2, day: 14))
        #expect(WeeklyEvent.lunarNewYearDay(year: 2027) == Day(year: 2027, month: 2, day: 6))
    }

    /// The winter and spring of the 1.0 launch, week by week (Mondays).
    @Test func winterAndSpring2027Schedule() {
        let expected: [(Int, Int, Int, String)] = [
            (2026, 11, 23, "thanksgiving"),
            (2026, 12, 21, "christmas"),
            (2026, 12, 28, "newyear"),
            (2027, 1, 18, "civilrights"),
            (2027, 2, 1, "biggame"),       // the game is on Valentine's Day, so a week early
            (2027, 2, 8, "valentines"),
            (2027, 2, 15, "lunarnewyear"), // Feb 1 and 8 are taken; still inside the festival
            (2027, 3, 8, "piday"),
            (2027, 3, 15, "stpatricks"),
            (2027, 3, 22, "easter"),
            (2027, 3, 29, "aprilfools"),
            (2027, 4, 19, "earthday"),
            (2027, 10, 25, "spooky"),
        ]
        for (y, m, d, event) in expected {
            for offset in 0..<7 {
                #expect(WeeklyEvent.event(on: Day(year: y, month: m, day: d) + offset).id == event, "\(y)-\(m)-\(d)")
            }
        }
    }

    @Test func weeksBeforeTheCalendarKeepTheirEvent() {
        // What testers already played must not change.
        #expect(id(2026, 11, 16) == "football")
        #expect(id(2026, 11, 9) == "nineties")
        #expect(id(2026, 11, 30) == "space")
    }

    @Test func everyRotationThemeRunsBeforeAnyRepeats() {
        var week = WeeklyEvent.rotationAnchorWeek
        var themes: [String] = []
        while themes.count < WeeklyEvent.rotation.count * 3 {
            let event = WeeklyEvent.event(week: week)
            if WeeklyEvent.rotation.contains(event) { themes.append(event.id) }
            week += 1
        }
        for start in stride(from: 0, to: themes.count, by: WeeklyEvent.rotation.count) {
            let cycle = themes[start..<start + WeeklyEvent.rotation.count]
            #expect(Set(cycle).count == WeeklyEvent.rotation.count, "\(cycle)")
        }
    }

    @Test func noHolidayIsCrowdedOutForYears() {
        for year in 2027...2036 {
            let placed = Set(WeeklyEvent.holidayWeeks(year: year).values.map(\.id))
            #expect(placed.count == WeeklyEvent.holidays.count, "\(year): \(placed)")
        }
    }

    @Test func noTwoWeeksInARowShareAnEvent() {
        let start = Day(year: 2026, month: 11, day: 2).weekIndex
        for week in start..<(start + 52 * 3) {
            #expect(WeeklyEvent.event(week: week) != WeeklyEvent.event(week: week + 1), "week \(week)")
        }
    }

    @Test func eventIDsAreUnique() {
        #expect(Set(WeeklyEvent.all.map(\.id)).count == WeeklyEvent.all.count)
    }
}
