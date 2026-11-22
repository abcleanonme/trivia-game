import Foundation

/// A themed week: a dedicated 10-question round you can replay, with event
/// points filling a progress track that ends in a cosmetic.
///
/// Themes are cut from the bank by category and a keyword pattern, so no
/// special question files are needed. Events rotate every week (Monday to
/// Sunday), so a missed one comes back in a later rotation. Two holiday
/// events take over their week instead: Spooky has the week with Halloween,
/// and Thanksgiving the week with U.S. Thanksgiving (fourth Thursday of
/// November).
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
    /// Fewest questions a theme needs to run.
    public static let minimumPool = 30

    public func matches(_ q: Question) -> Bool {
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

    public static let all: [WeeklyEvent] = rotation + [spooky, thanksgiving]

    /// The event running on a day.
    public static func event(on day: Day) -> WeeklyEvent {
        let year = day.components.year!
        if Day(year: year, month: 10, day: 31).weekIndex == day.weekIndex { return spooky }
        if thanksgivingDay(year: year).weekIndex == day.weekIndex { return thanksgiving }
        let i = ((day.weekIndex % rotation.count) + rotation.count) % rotation.count
        return rotation[i]
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
        let first = Day(year: year, month: 11, day: 1)
        // Day ordinal 0 (1970-01-01) was a Thursday.
        let toThursday = ((-first.ordinal % 7) + 7) % 7
        return first + toThursday + 21
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
