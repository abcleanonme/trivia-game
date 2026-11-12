import Foundation

/// What a round was for, so the right trackers get credit.
public enum RoundKind: Equatable, Sendable {
    case solo
    case daily(Day)
    case event(WeeklyEvent, week: Int)
}

/// Everything a finished round earned beyond its points.
public struct RoundRewards: Equatable, Sendable {
    /// Round Sparks (1 per 10 points) plus every bonus below.
    public var sparks = 0
    public var dailyBonus = 0
    public var levelUps: [LevelUp] = []
    public var eventSparks = 0
    public var eventCompleted: WeeklyEvent?
    public var newStamps: [Stamp] = []
    public var unlocked: [Cosmetic] = []
    public var daily: DailyRecord?
    public var streakChange: DailyStreak.Change?

    public struct LevelUp: Equatable, Sendable {
        public let category: String
        public let level: Int
        public var sparks: Int { Mastery.sparks(forLevel: level) }
    }

    public var bonusSparks: Int {
        dailyBonus + eventSparks + levelUps.reduce(0) { $0 + $1.sparks }
    }

    public var isEmpty: Bool {
        bonusSparks == 0 && newStamps.isEmpty && unlocked.isEmpty && daily == nil
    }
}

/// Lifetime counters behind stamps and Player Card stats.
public struct PlayerStats: Codable, Equatable, Sendable {
    public var roundsPlayed = 0
    public var questionsAnswered = 0
    public var correctAnswers = 0
    public var bestStreak = 0
    public var dailiesPlayed = 0
    public var bestSurvival = 0
    public var bestSpeedRound = 0

    public init() {}
}

/// The player's long-term progress, saved as one value. Pure logic so the
/// rules are unit-tested; `PlayerStore` in the app persists it.
public struct PlayerProgress: Codable, Equatable, Sendable {
    public var stats = PlayerStats()
    public var streak = DailyStreak()
    public var dailies: [Day: DailyRecord] = [:]
    /// Correct answers per category.
    public var masteryCorrect: [String: Int] = [:]
    public var events: [String: EventProgress] = [:]
    public var rivals = RivalryBook()
    public var submissions: [QuestionSubmission] = []
    public var reports: [QuestionReport] = []
    public var inventory = Inventory()
    public var card = PlayerCard()
    public private(set) var stamps: Set<Stamp> = []

    public init() {}

    // MARK: Reading

    public func masteryLevel(_ category: String) -> Int {
        Mastery.level(forCorrect: masteryCorrect[category, default: 0])
    }

    public var topCategory: String? {
        masteryCorrect.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key
    }

    /// Titles the player can pick for their card, default first.
    public var titles: [String] {
        [Stamp.defaultTitle] + stamps.compactMap(\.title).sorted()
    }

    public func hasPlayedDaily(on day: Day) -> Bool { dailies[day] != nil }

    public func eventProgress(_ event: WeeklyEvent, week: Int) -> EventProgress {
        events[WeeklyEvent.instanceID(event, week: week)] ?? EventProgress()
    }

    public func showcaseValue(on today: Day) -> String {
        switch card.showcase {
        case .bestStreak: "\(stats.bestStreak)"
        case .dailyStreak: "\(streak.current(on: today)) days"
        case .dailiesPlayed: "\(stats.dailiesPlayed)"
        case .wins: "\(rivals.totalWins)"
        case .topCategory: topCategory ?? "None yet"
        }
    }

    // MARK: Daily attempts

    /// Starts today's one attempt. Returns false if it's already used.
    public mutating func beginDaily(on day: Day, relaxed: Bool) -> Bool {
        guard dailies[day] == nil else { return false }
        dailies[day] = DailyRecord(day: day, relaxed: relaxed)
        return true
    }

    // MARK: Recording a round

    /// Credits a finished round to every tracker and returns what it earned.
    /// `finished` is false when the player quit (only the Daily records that).
    public mutating func record(_ session: GameSession, kind: RoundKind,
                                finished: Bool = true) -> RoundRewards {
        var rewards = RoundRewards()
        let results = session.results

        if finished {
            stats.roundsPlayed += 1
            stats.questionsAnswered += results.count
            stats.correctAnswers += session.correctCount
            stats.bestStreak = max(stats.bestStreak, session.bestStreak)
            switch session.mode {
            case .survival: stats.bestSurvival = max(stats.bestSurvival, session.correctCount)
            case .speed: stats.bestSpeedRound = max(stats.bestSpeedRound, session.correctCount)
            case .classic: break
            }
            rewards.sparks = session.sparksEarned
        }

        // Mastery counts every correct answer, even in a round you left.
        var gained: [String: Int] = [:]
        for r in results where r.correct { gained[r.question.category, default: 0] += 1 }
        for (category, n) in gained.sorted(by: { $0.key < $1.key }) {
            let before = masteryLevel(category)
            masteryCorrect[category, default: 0] += n
            let after = masteryLevel(category)
            guard after > before else { continue }
            for level in (before + 1)...after {
                rewards.levelUps.append(.init(category: category, level: level))
                if Mastery.badgeLevels.contains(level) {
                    earn(.mastery(category: category, level: level), into: &rewards)
                }
            }
        }

        if finished {
            if results.count >= GameRules.questionsPerRound, session.correctCount == results.count {
                earn(.perfectRound, into: &rewards)
            }
            if session.bestStreak >= 10 { earn(.tenStreak, into: &rewards) }
            let fastRight = results.filter { DailyMark($0).fast && $0.correct }.count
            if fastRight >= 5 { earn(.speedDemon, into: &rewards) }
        }

        switch kind {
        case .solo:
            break
        case .daily(let day):
            var record = dailies[day] ?? DailyRecord(day: day, relaxed: !session.isTimed)
            record.marks = results.map(DailyMark.init)
            record.points = session.totalPoints
            record.finished = finished
            if finished {
                rewards.streakChange = streak.record(day)
                stats.dailiesPlayed += 1
                rewards.dailyBonus = DailyChallenge.bonus(correct: session.correctCount, total: results.count)
                for step in Stamp.dailyStreakSteps where streak.count >= step {
                    earn(.dailyStreak(step), into: &rewards)
                }
                if stats.dailiesPlayed >= 100 { earn(.hundredDailies, into: &rewards) }
            }
            record.streak = streak.current(on: day)
            dailies[day] = record
            rewards.daily = record
        case .event(let event, let week):
            guard finished else { break }
            let id = WeeklyEvent.instanceID(event, week: week)
            var progress = events[id] ?? EventProgress()
            let (sparks, completed) = progress.add(points: session.totalPoints)
            events[id] = progress
            rewards.eventSparks = sparks
            if completed {
                rewards.eventCompleted = event
                earn(.eventComplete(event.id), into: &rewards)
                if inventory.grant(event.rewardID), let item = CosmeticCatalog.item(event.rewardID) {
                    rewards.unlocked.append(item)
                }
            }
        }

        rewards.sparks += rewards.bonusSparks
        return rewards
    }

    /// Records a friend match (called by the multiplayer layer).
    public mutating func recordMatch(_ outcome: MatchOutcome, against friendID: String, name: String,
                                     at date: Date = Date()) -> [Stamp] {
        var rewards = RoundRewards()
        for stamp in rivals.add(outcome, against: friendID, name: name, at: date) {
            earn(stamp, into: &rewards)
        }
        if rivals.totalWins >= 50 { earn(.fiftyWins, into: &rewards) }
        return rewards.newStamps
    }

    // MARK: Submissions

    public mutating func submit(_ submission: QuestionSubmission) {
        submissions.insert(submission, at: 0)
    }

    /// Applies a review decision. Accepted questions pay Sparks and the
    /// Question Writer stamp once. Returns the Sparks to add to the wallet.
    public mutating func updateSubmission(_ id: UUID, to status: QuestionSubmission.Status) -> Int {
        guard let i = submissions.firstIndex(where: { $0.id == id }) else { return 0 }
        submissions[i].status = status
        guard status == .accepted, !submissions[i].rewarded else { return 0 }
        submissions[i].rewarded = true
        var rewards = RoundRewards()
        earn(.questionWriter, into: &rewards)
        return QuestionSubmission.acceptedSparks
    }

    // MARK: Private

    private mutating func earn(_ stamp: Stamp, into rewards: inout RoundRewards) {
        guard stamps.insert(stamp).inserted else { return }
        rewards.newStamps.append(stamp)
        for item in CosmeticCatalog.all where item.unlock == .stamp(stamp) {
            if inventory.grant(item.id) { rewards.unlocked.append(item) }
        }
    }

    // Tolerant decoding: fields added in later versions start empty instead
    // of wiping a saved profile.
    private enum CodingKeys: String, CodingKey {
        case stats, streak, dailies, masteryCorrect, events, rivals, submissions, reports, inventory, card, stamps
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats = try c.decodeIfPresent(PlayerStats.self, forKey: .stats) ?? PlayerStats()
        streak = try c.decodeIfPresent(DailyStreak.self, forKey: .streak) ?? DailyStreak()
        let dailyList = try c.decodeIfPresent([DailyRecord].self, forKey: .dailies) ?? []
        dailies = Dictionary(dailyList.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        masteryCorrect = try c.decodeIfPresent([String: Int].self, forKey: .masteryCorrect) ?? [:]
        events = try c.decodeIfPresent([String: EventProgress].self, forKey: .events) ?? [:]
        rivals = try c.decodeIfPresent(RivalryBook.self, forKey: .rivals) ?? RivalryBook()
        submissions = try c.decodeIfPresent([QuestionSubmission].self, forKey: .submissions) ?? []
        reports = try c.decodeIfPresent([QuestionReport].self, forKey: .reports) ?? []
        inventory = try c.decodeIfPresent(Inventory.self, forKey: .inventory) ?? Inventory()
        card = try c.decodeIfPresent(PlayerCard.self, forKey: .card) ?? PlayerCard()
        stamps = try c.decodeIfPresent(Set<Stamp>.self, forKey: .stamps) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stats, forKey: .stats)
        try c.encode(streak, forKey: .streak)
        try c.encode(dailies.values.sorted { $0.day < $1.day }, forKey: .dailies)
        try c.encode(masteryCorrect, forKey: .masteryCorrect)
        try c.encode(events, forKey: .events)
        try c.encode(rivals, forKey: .rivals)
        try c.encode(submissions, forKey: .submissions)
        try c.encode(reports, forKey: .reports)
        try c.encode(inventory, forKey: .inventory)
        try c.encode(card, forKey: .card)
        try c.encode(stamps, forKey: .stamps)
    }
}
