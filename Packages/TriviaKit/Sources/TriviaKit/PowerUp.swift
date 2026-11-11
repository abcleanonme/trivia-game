import Foundation

/// Power-ups from the design spec (design/points-and-powerups.md).
///
/// Bought with Sparks only. Rules that keep the game classic:
/// at most one per question, at most `GameRules.soloPowerUpsPerRound` per
/// solo round, and using one forfeits that question's speed bonus.
public enum PowerUp: String, CaseIterable, Codable, Sendable, Identifiable {
    case fiftyFifty
    case extraTime
    case skip
    case secondChance
    case doubleDown

    public var id: String { rawValue }

    /// Price in Sparks.
    public var cost: Int {
        switch self {
        case .fiftyFifty: 30
        case .extraTime: 20
        case .skip: 25
        case .secondChance: 40
        case .doubleDown: 35
        }
    }

    public var title: String {
        switch self {
        case .fiftyFifty: "50/50"
        case .extraTime: "+10s"
        case .skip: "Skip"
        case .secondChance: "Second chance"
        case .doubleDown: "Double down"
        }
    }

    /// Fits a quarter-width tray tile.
    public var shortTitle: String {
        switch self {
        case .doubleDown: "2x"
        case .secondChance: "Retry"
        default: title
        }
    }

    public var summary: String {
        switch self {
        case .fiftyFifty: "Removes two wrong answers"
        case .extraTime: "Adds 10 seconds"
        case .skip: "Swaps the question, keeps your streak, no points"
        case .secondChance: "One retry after a miss, for half points"
        case .doubleDown: "Double points on this question. A miss resets your streak"
        }
    }

    public var systemImage: String {
        switch self {
        case .fiftyFifty: "circle.lefthalf.filled"
        case .extraTime: "timer"
        case .skip: "forward.end"
        case .secondChance: "arrow.uturn.backward"
        case .doubleDown: "multiply"
        }
    }

    /// Power-ups you choose *before* answering. Second chance is offered
    /// only after a miss, so it lives on the feedback bar instead.
    public static let trayOrder: [PowerUp] = [.fiftyFifty, .extraTime, .skip, .doubleDown]
}
