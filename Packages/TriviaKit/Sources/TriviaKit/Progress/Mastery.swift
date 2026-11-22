import Foundation

/// Category mastery: levels 1–10 from correct answers in a category.
/// Levels 5 and 10 unlock that category's badge (a Player Card stamp).
public enum Mastery {
    /// Correct answers needed to *reach* each level (index 0 is level 1).
    public static let thresholds = [25, 75, 150, 300, 500, 600, 700, 800, 900, 1_000]
    public static let maxLevel = thresholds.count
    public static let badgeLevels: Set<Int> = [5, 10]

    public static func level(forCorrect correct: Int) -> Int {
        thresholds.lastIndex { correct >= $0 }.map { $0 + 1 } ?? 0
    }

    /// Sparks for reaching a level.
    public static func sparks(forLevel level: Int) -> Int { 25 * level }

    /// Progress toward the next level, 0...1 (1 at max level).
    public static func progress(forCorrect correct: Int) -> Double {
        let level = level(forCorrect: correct)
        guard level < maxLevel else { return 1 }
        let floor = level == 0 ? 0 : thresholds[level - 1]
        let next = thresholds[level]
        return Double(correct - floor) / Double(next - floor)
    }

    /// Correct answers still needed for the next level (0 at max level).
    public static func remaining(forCorrect correct: Int) -> Int {
        let level = level(forCorrect: correct)
        return level < maxLevel ? thresholds[level] - correct : 0
    }
}
