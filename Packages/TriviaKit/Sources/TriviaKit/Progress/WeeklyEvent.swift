import Foundation

/// A themed week: a dedicated 10-question round you can replay, with event
/// points filling a progress track that ends in a cosmetic.
///
/// Themes are cut from the bank by category and a keyword pattern, so no
/// special question files are needed. Events rotate every week (Monday to
/// Sunday), so a missed one comes back in a later rotation; Spooky always
/// takes the week with Halloween.
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

    public static let all: [WeeklyEvent] = rotation + [spooky]

    /// The event running on a day.
    public static func event(on day: Day) -> WeeklyEvent {
        let year = day.components.year!
        if Day(year: year, month: 10, day: 31).weekIndex == day.weekIndex { return spooky }
        let i = ((day.weekIndex % rotation.count) + rotation.count) % rotation.count
        return rotation[i]
    }
}

/// Points earned toward one run of a weekly event.
public struct EventProgress: Codable, Equatable, Sendable {
    public var points = 0
    public var rounds = 0
    /// Number of milestones already paid out.
    public var milestonesPaid = 0
    public var completed = false

    public init() {}

    public var fraction: Double { min(Double(points) / Double(WeeklyEvent.trackLength), 1) }

    /// Adds a round's points. Returns Sparks for any milestones passed and
    /// whether the track was just completed.
    public mutating func add(points earned: Int) -> (sparks: Int, justCompleted: Bool) {
        points += max(earned, 0)
        rounds += 1
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
}
