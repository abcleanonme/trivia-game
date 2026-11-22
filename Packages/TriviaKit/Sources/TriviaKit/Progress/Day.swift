import Foundation

/// A calendar date in the player's own time zone, stored as a whole number of
/// days. Daily challenges, streaks and weekly events all count in these, so
/// "a new set at local midnight" and "days in a row" are plain integer math.
public struct Day: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    /// Days since 1970-01-01 for the *local* calendar date (not UTC instants).
    public let ordinal: Int

    public init(ordinal: Int) { self.ordinal = ordinal }

    public init(_ date: Date, timeZone: TimeZone = .current) {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let c = local.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public init(year: Int, month: Int, day: Int) {
        let utc = Self.utcCalendar
        let date = utc.date(from: DateComponents(year: year, month: month, day: day))!
        ordinal = Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    public static func today(timeZone: TimeZone = .current) -> Day { Day(Date(), timeZone: timeZone) }

    /// The day Quizio's Daily started. Daily #1.
    public static let launch = Day(year: 2026, month: 11, day: 11)

    /// "Daily #12" style number shown on the share card.
    public var dailyNumber: Int { ordinal - Self.launch.ordinal + 1 }

    /// Weeks run Monday to Sunday. 1970-01-01 was a Thursday.
    public var weekIndex: Int { Self.floorDiv(ordinal + 3, 7) }
    public var weekStart: Day { Day(ordinal: weekIndex * 7 - 3) }

    public var components: DateComponents {
        Self.utcCalendar.dateComponents([.year, .month, .day],
                                        from: Date(timeIntervalSince1970: Double(ordinal) * 86_400))
    }

    public static func + (lhs: Day, rhs: Int) -> Day { Day(ordinal: lhs.ordinal + rhs) }
    public static func - (lhs: Day, rhs: Day) -> Int { lhs.ordinal - rhs.ordinal }
    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.ordinal < rhs.ordinal }

    public var description: String {
        let c = components
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        (a - ((a % b) + b) % b) / b
    }
}

/// A small, fast, *portable* seeded generator (SplitMix64). The Daily uses it
/// so every player's phone deals the same ten questions for the same date;
/// `SystemRandomNumberGenerator` can't be seeded.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
