import Foundation

/// A themed week: a dedicated 10-question round you can replay, with event
/// points filling a progress track that ends in a cosmetic.
///
/// Themes are cut from the bank by category and a keyword pattern, plus any
/// questions tagged for the event (`Question.event`, from `events.json`).
/// Events rotate every week (Monday to Sunday), so a missed one comes back
/// in a later rotation. Holiday events take over the week their day falls
/// in; see `holidays` for the list and how clashes are settled.
public struct WeeklyEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let blurb: String
    public let systemImage: String
    /// Only these categories, or any category when nil.
    public let categories: Set<String>?
    /// Case-insensitive regular expression matched against the prompt.
    public let pattern: String
    /// Cosmetic id unlocked at the end of the track.
    public let rewardID: String

    /// Event points needed to fill the track (about three good rounds).
    public static let trackLength = 3_000
    /// Sparks for passing 1/4, 1/2 and 3/4 of the track.
    public static let milestones: [(fraction: Double, sparks: Int)] = [(0.25, 25), (0.5, 50), (0.75, 75)]
    /// Fewest questions a theme needs to run: five rounds before any repeat.
    public static let minimumPool = 50

    public func matches(_ q: Question) -> Bool {
        // A question written for an event belongs to that event only.
        if let tag = q.event { return tag == id }
        if let categories, !categories.contains(q.category) { return false }
        return q.prompt.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    public func pool(from bank: QuestionBank) -> QuestionBank {
        QuestionBank(questions: bank.questions.filter(matches))
    }

    /// Progress is kept per *run* of an event, so a returning theme starts
    /// a fresh track (its cosmetic, once earned, stays earned).
    public static func instanceID(_ event: WeeklyEvent, week: Int) -> String { "\(event.id)@\(week)" }

    // MARK: Schedule

    public static let spooky = WeeklyEvent(
        id: "spooky", title: "Spooky Week", blurb: "Ghosts, monsters and horror classics.",
        systemImage: "moon.stars.fill", categories: nil,
        pattern: #"\b(horror|ghost|halloween|vampire|zombie|witch|monster|haunted|dracula|skeleton)"#,
        rewardID: "bg.event.spooky")

    /// Lowercase-only matches for turkey, cranberry and pumpkin, so the
    /// country Turkey, The Cranberries and the Smashing Pumpkins stay out.
    public static let thanksgiving = WeeklyEvent(
        id: "thanksgiving", title: "Thanksgiving Feast", blurb: "Pilgrims, parades, football and the big dinner.",
        systemImage: "leaf.fill", categories: nil,
        pattern: #"thanksgiving|mayflower|wampanoag|plymouth|pilgrims\b|cornucopia|gobble|turducken|(?-i:\bturkeys?\b|cranberr|pumpkin)"#,
        rewardID: "emblem.event.thanksgiving")

    public static let christmas = WeeklyEvent(
        id: "christmas", title: "Christmas Week", blurb: "Santa, carols, classic films and festive traditions.",
        systemImage: "gift.fill", categories: nil,
        pattern: #"christmas|santa claus|reindeer|rudolph|mistletoe|nutcracker|yuletide|gingerbread|nativity|scrooge|grinch|north pole|jingle bells|poinsettia|eggnog"#,
        rewardID: "bg.event.christmas")

    public static let newYear = WeeklyEvent(
        id: "newyear", title: "New Year Countdown", blurb: "Midnight traditions, resolutions and a look back.",
        systemImage: "party.popper.fill", categories: nil,
        pattern: #"new year|auld lang syne|hogmanay|ball drop"#,
        rewardID: "emblem.event.newyear")

    public static let civilRights = WeeklyEvent(
        id: "civilrights", title: "Dream Week", blurb: "Dr. King and the people of the civil rights movement.",
        systemImage: "megaphone.fill", categories: nil,
        pattern: #"martin luther king|civil rights|rosa parks|montgomery bus|selma|segregat|malcolm x|harriet tubman|frederick douglass|underground railroad|emancipation proclamation|naacp|jim crow|brown v\.? board|thurgood marshall|jackie robinson"#,
        rewardID: "emblem.event.civilrights")

    public static let lunarNewYear = WeeklyEvent(
        id: "lunarnewyear", title: "Lunar New Year", blurb: "Zodiac animals, lanterns, dumplings and red envelopes.",
        systemImage: "moon.circle.fill", categories: nil,
        pattern: #"lunar new year|chinese new year|chinese zodiac|red envelope|lantern festival|spring festival|year of the (rat|ox|tiger|rabbit|dragon|snake|horse|goat|monkey|rooster|dog|pig)\b"#,
        rewardID: "border.event.lunarnewyear")

    /// Named "Big Game" rather than the NFL's trademark.
    public static let bigGame = WeeklyEvent(
        id: "biggame", title: "Big Game Week", blurb: "Touchdowns, legends and famous halftime shows.",
        systemImage: "football.fill", categories: nil,
        pattern: #"super bowl|\bnfl\b|touchdown|quarterback|american football|lombardi trophy|halftime show|end zone|field goal"#,
        rewardID: "emblem.event.biggame")

    /// Lowercase-only "romantic", so the Romantic art movement stays out.
    public static let valentines = WeeklyEvent(
        id: "valentines", title: "Sweetheart Week", blurb: "Love songs, famous couples and Valentine's lore.",
        systemImage: "heart.fill", categories: nil,
        pattern: #"valentine|cupid|sweetheart|romeo and juliet|love letter|(?-i:\bromantic)"#,
        rewardID: "bg.event.valentines")

    public static let piDay = WeeklyEvent(
        id: "piday", title: "Pi Day", blurb: "Numbers, shapes and the mathematicians behind them.",
        systemImage: "function", categories: nil,
        pattern: #"\bpi\b|mathematician|pythagor|prime number|square root|geometry(?! dash)|algebra|calculus"#,
        rewardID: "emblem.event.piday")

    public static let stPatricks = WeeklyEvent(
        id: "stpatricks", title: "Luck of the Irish", blurb: "Shamrocks, legends and all things Ireland.",
        systemImage: "leaf.circle.fill", categories: nil,
        pattern: #"st\.? patrick|ireland|irish|dublin|shamrock|leprechaun|emerald isle|belfast"#,
        rewardID: "border.event.stpatricks")

    public static let easter = WeeklyEvent(
        id: "easter", title: "Egg Hunt", blurb: "Bunnies, spring and hidden Easter eggs in games and films.",
        systemImage: "hare.fill", categories: nil,
        pattern: #"\beaster\b|bunny|bunnies|jelly bean|egg hunt|daffodil|hot cross"#,
        rewardID: "bg.event.easter")

    public static let aprilFools = WeeklyEvent(
        id: "aprilfools", title: "Fact or Fool", blurb: "Famous hoaxes, pranks and facts that sound fake.",
        systemImage: "theatermasks.fill", categories: nil,
        pattern: #"april fool|hoax|\bprank|practical joke|misconception"#,
        rewardID: "emblem.event.aprilfools")

    public static let earthDay = WeeklyEvent(
        id: "earthday", title: "Earth Week", blurb: "Forests, oceans, wildlife and keeping the planet green.",
        systemImage: "globe.americas.fill", categories: nil,
        pattern: #"earth day|recycl|rainforest|endangered|pollution|renewable energy|ecosystem|national park|deforest|greenhouse gas|ozone layer|climate change"#,
        rewardID: "bg.event.earthday")

    /// A holiday event and the day it celebrates in a given year.
    public struct Holiday: Sendable {
        public let event: WeeklyEvent
        /// The holiday's date in a year, or nil if unknown for that year.
        public let date: @Sendable (_ year: Int) -> Day?
        /// Weeks to try, relative to the week the date falls in, in order.
        /// When every one is taken by a holiday earlier in `holidays`, the
        /// event sits that year out.
        public let weeks: [Int]
    }

    /// Holidays that take over their week, most important first. When two
    /// land in the same week, the later one moves to its next allowed week
    /// (Big Game a week early when the game falls on Valentine's Day, as in
    /// 2027) or skips the year.
    public static let holidays: [Holiday] = [
        Holiday(event: christmas, date: { Day(year: $0, month: 12, day: 25) }, weeks: [0]),
        Holiday(event: newYear, date: { Day(year: $0, month: 1, day: 1) }, weeks: [0]),
        Holiday(event: thanksgiving, date: { WeeklyEvent.thanksgivingDay(year: $0) }, weeks: [0]),
        Holiday(event: spooky, date: { Day(year: $0, month: 10, day: 31) }, weeks: [0]),
        Holiday(event: valentines, date: { Day(year: $0, month: 2, day: 14) }, weeks: [0]),
        Holiday(event: easter, date: { WeeklyEvent.easterSunday(year: $0) }, weeks: [0]),
        Holiday(event: stPatricks, date: { Day(year: $0, month: 3, day: 17) }, weeks: [0, -1]),
        Holiday(event: bigGame, date: { WeeklyEvent.nth(2, weekday: 6, month: 2, year: $0) }, weeks: [0, -1]),
        Holiday(event: civilRights, date: { WeeklyEvent.nth(3, weekday: 0, month: 1, year: $0) }, weeks: [0]),
        Holiday(event: lunarNewYear, date: { WeeklyEvent.lunarNewYearDay(year: $0) }, weeks: [0, 1, 2]),
        Holiday(event: piDay, date: { Day(year: $0, month: 3, day: 14) }, weeks: [0, -1]),
        Holiday(event: aprilFools, date: { Day(year: $0, month: 4, day: 1) }, weeks: [0, 1]),
        Holiday(event: earthDay, date: { Day(year: $0, month: 4, day: 22) }, weeks: [0, -1, 1]),
    ]

    /// Which week each holiday of `year` takes, keyed by `Day.weekIndex`.
    public static func holidayWeeks(year: Int) -> [Int: WeeklyEvent] {
        var taken: [Int: WeeklyEvent] = [:]
        for holiday in holidays {
            guard let date = holiday.date(year) else { continue }
            if let week = holiday.weeks.map({ date.weekIndex + $0 }).first(where: { taken[$0] == nil }) {
                taken[week] = holiday.event
            }
        }
        return taken
    }

    /// The regular rotation, in order.
    public static let rotation: [WeeklyEvent] = [
        WeeklyEvent(id: "space", title: "Space Week", blurb: "Planets, rockets and the stars.",
                    systemImage: "moon.stars", categories: nil,
                    pattern: #"\b(planet|moon|nasa|orbit|astronaut|galaxy|solar|mars|jupiter|saturn|comet|telescope|apollo|space)\b"#,
                    rewardID: "emblem.event.space"),
        WeeklyEvent(id: "eighties", title: "Totally 80s", blurb: "Hits, films and games from the 1980s.",
                    systemImage: "music.note", categories: nil,
                    pattern: #"198\d|\b80s\b|eighties"#,
                    rewardID: "bg.event.eighties"),
        WeeklyEvent(id: "animals", title: "Wild Week", blurb: "Creatures great and small.",
                    systemImage: "pawprint.fill", categories: nil,
                    pattern: #"\b(animal|mammal|bird|fish|shark|whale|dog|cat|lion|tiger|bear|insect|species)"#,
                    rewardID: "border.event.animals"),
        WeeklyEvent(id: "myths", title: "Myths and Legends", blurb: "Gods, heroes and monsters of old.",
                    systemImage: "building.columns.fill", categories: nil,
                    pattern: #"\b(god|goddess|myth|mythology|zeus|thor|odin|greek|norse|legend)"#,
                    rewardID: "emblem.event.myths"),
        WeeklyEvent(id: "capitals", title: "Capital Cities", blurb: "Name that capital.",
                    systemImage: "globe.europe.africa.fill", categories: ["Geography", "History", "General"],
                    pattern: #"capital"#,
                    rewardID: "bg.event.capitals"),
        WeeklyEvent(id: "retro", title: "Retro Games", blurb: "Plumbers, hedgehogs and pocket monsters.",
                    systemImage: "gamecontroller.fill", categories: nil,
                    pattern: #"nintendo|mario|zelda|pok[eé]mon|sega|sonic|playstation|atari|arcade"#,
                    rewardID: "emblem.event.retro"),
        WeeklyEvent(id: "ocean", title: "Ocean Week", blurb: "Seas, islands and what lives in them.",
                    systemImage: "water.waves", categories: nil,
                    pattern: #"\b(ocean|sea|island|coral|whale|shark|reef|tide)"#,
                    rewardID: "bg.event.ocean"),
        WeeklyEvent(id: "nineties", title: "90s Throwback", blurb: "The decade of dial-up and boy bands.",
                    systemImage: "tv.fill", categories: nil,
                    pattern: #"199\d|\b90s\b|nineties"#,
                    rewardID: "border.event.nineties"),
        WeeklyEvent(id: "football", title: "Football Fever", blurb: "Clubs, cups and legends of the beautiful game.",
                    systemImage: "soccerball", categories: nil,
                    pattern: #"soccer|football club|premier league|fifa|world cup|la liga|bundesliga"#,
                    rewardID: "emblem.event.football"),
        WeeklyEvent(id: "food", title: "Food Fight", blurb: "Dishes, drinks and kitchen lore.",
                    systemImage: "fork.knife", categories: nil,
                    pattern: #"\b(food|dish|cheese|fruit|vegetable|cuisine|bread|sauce|chocolate|coffee|tea|wine|beer|pizza)"#,
                    rewardID: "bg.event.food"),
    ]

    public static let all: [WeeklyEvent] = rotation + holidays.map(\.event)

    /// The event running on a day.
    public static func event(on day: Day) -> WeeklyEvent {
        let year = day.components.year!
        // A week can hold a holiday of the next year (New Year's week starts
        // in December) or, after a move, of the year before.
        for y in [year, year + 1, year - 1] {
            if let holiday = holidayWeeks(year: y)[day.weekIndex] { return holiday }
        }
        return rotationEvent(week: day.weekIndex)
    }

    /// From this week on, the rotation counts only weeks without a holiday,
    /// so every theme gets its turn before any repeats. Earlier weeks keep
    /// the original schedule, so past results still line up.
    public static let rotationAnchorWeek = Day(year: 2026, month: 11, day: 30).weekIndex

    static func rotationEvent(week: Int) -> WeeklyEvent {
        let n = rotation.count
        guard week > rotationAnchorWeek else { return rotation[((week % n) + n) % n] }
        let firstYear = Day.firstDay(ofWeek: rotationAnchorWeek).components.year!
        let lastYear = Day.firstDay(ofWeek: week).components.year!
        var taken = Set<Int>()
        for year in (firstYear - 1)...(lastYear + 1) { taken.formUnion(holidayWeeks(year: year).keys) }
        let skipped = taken.filter { $0 >= rotationAnchorWeek && $0 < week }.count
        return rotation[(rotationAnchorWeek % n + week - rotationAnchorWeek - skipped) % n]
    }

    /// The event for a week number (`Day.weekIndex`).
    public static func event(week: Int) -> WeeklyEvent { event(on: Day.firstDay(ofWeek: week)) }

    /// The next `count` weeks after the one `day` is in, soonest first.
    public static func upcoming(after day: Day, count: Int) -> [EventWeek] {
        (1...max(count, 1)).map { offset in
            let week = day.weekIndex + offset
            return EventWeek(event: event(week: week), week: week)
        }
    }

    /// Splits an `instanceID` back into the event and week. nil for ids of
    /// events no longer in the app.
    public static func parseInstanceID(_ id: String) -> (event: WeeklyEvent, week: Int)? {
        let parts = id.split(separator: "@")
        guard parts.count == 2, let week = Int(parts[1]),
              let event = all.first(where: { $0.id == parts[0] }) else { return nil }
        return (event, week)
    }

    /// U.S. Thanksgiving: the fourth Thursday of November.
    public static func thanksgivingDay(year: Int) -> Day {
        nth(4, weekday: 3, month: 11, year: year)
    }

    /// The `n`th `weekday` (0 is Monday, 6 is Sunday) of a month.
    public static func nth(_ n: Int, weekday: Int, month: Int, year: Int) -> Day {
        let first = Day(year: year, month: month, day: 1)
        let firstWeekday = first - first.weekStart
        return first + (weekday - firstWeekday + 7) % 7 + 7 * (n - 1)
    }

    /// Western (Gregorian) Easter Sunday, by the anonymous Gregorian algorithm.
    public static func easterSunday(year: Int) -> Day {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return Day(year: year, month: month, day: day)
    }

    /// Lunar New Year has no simple formula, so the dates are listed. Add
    /// more years before 2036 runs out (the event just skips unlisted years).
    public static let lunarNewYearDates: [Day] = [
        Day(year: 2027, month: 2, day: 6), Day(year: 2028, month: 1, day: 26),
        Day(year: 2029, month: 2, day: 13), Day(year: 2030, month: 2, day: 3),
        Day(year: 2031, month: 1, day: 23), Day(year: 2032, month: 2, day: 11),
        Day(year: 2033, month: 1, day: 31), Day(year: 2034, month: 2, day: 19),
        Day(year: 2035, month: 2, day: 8), Day(year: 2036, month: 1, day: 28),
    ]

    public static func lunarNewYearDay(year: Int) -> Day? {
        lunarNewYearDates.first { $0.components.year == year }
    }
}

/// Points earned toward one run of a weekly event.
public struct EventProgress: Codable, Equatable, Sendable {
    public var points = 0
    public var rounds = 0
    /// Number of milestones already paid out.
    public var milestonesPaid = 0
    public var completed = false
    /// Best single timed round this week. This is what the weekly friends
    /// leaderboard ranks, so replaying more doesn't beat playing well, and
    /// relaxed (no clock) rounds never rank against timed ones.
    public var bestRound = 0

    public init() {}

    public var fraction: Double { min(Double(points) / Double(WeeklyEvent.trackLength), 1) }

    /// Adds a round's points. Returns Sparks for any milestones passed and
    /// whether the track was just completed.
    public mutating func add(points earned: Int, timed: Bool = true) -> (sparks: Int, justCompleted: Bool) {
        points += max(earned, 0)
        rounds += 1
        if timed { bestRound = max(bestRound, earned) }
        var sparks = 0
        while milestonesPaid < WeeklyEvent.milestones.count,
              fraction >= WeeklyEvent.milestones[milestonesPaid].fraction {
            sparks += WeeklyEvent.milestones[milestonesPaid].sparks
            milestonesPaid += 1
        }
        let finishedNow = !completed && points >= WeeklyEvent.trackLength
        if finishedNow { completed = true }
        return (sparks, finishedNow)
    }

    // Tolerant decoding: saves from before `bestRound` existed still load.
    private enum CodingKeys: String, CodingKey {
        case points, rounds, milestonesPaid, completed, bestRound
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 0
        milestonesPaid = try c.decodeIfPresent(Int.self, forKey: .milestonesPaid) ?? 0
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        bestRound = try c.decodeIfPresent(Int.self, forKey: .bestRound) ?? 0
    }
}

/// One week of the event calendar: which event ran (or will run), and what
/// the player did in it.
public struct EventWeek: Identifiable, Equatable, Sendable {
    public let event: WeeklyEvent
    public let week: Int
    public let progress: EventProgress

    public init(event: WeeklyEvent, week: Int, progress: EventProgress = EventProgress()) {
        self.event = event
        self.week = week
        self.progress = progress
    }

    public var id: String { WeeklyEvent.instanceID(event, week: week) }
    /// Monday.
    public var start: Day { Day.firstDay(ofWeek: week) }
    /// Sunday.
    public var end: Day { start + 6 }
}
