import Foundation

/// What the player keeps between rounds: Sparks and power-up stock.
/// Sparks are earned only by playing and are never sold.
public struct Wallet: Codable, Equatable, Sendable {
    public private(set) var sparks: Int
    public private(set) var stock: [PowerUp: Int]

    public init(sparks: Int = 0, stock: [PowerUp: Int] = [:]) {
        self.sparks = sparks
        self.stock = stock
    }

    /// A new player's free starter kit, so the tray isn't empty on round one.
    public static let starter = Wallet(sparks: 0, stock: [
        .fiftyFifty: 2, .extraTime: 2, .skip: 1, .secondChance: 1, .doubleDown: 1,
    ])

    public func count(of powerUp: PowerUp) -> Int { stock[powerUp, default: 0] }

    /// Removes one from stock. Returns false if there were none.
    @discardableResult
    public mutating func consume(_ powerUp: PowerUp) -> Bool {
        guard count(of: powerUp) > 0 else { return false }
        stock[powerUp, default: 0] -= 1
        return true
    }

    public mutating func earn(sparks amount: Int) {
        sparks += max(amount, 0)
    }

    /// Spends Sparks (e.g. on a cosmetic). Returns false if the player can't afford it.
    @discardableResult
    public mutating func spend(_ amount: Int) -> Bool {
        guard amount >= 0, sparks >= amount else { return false }
        sparks -= amount
        return true
    }

    /// Spends Sparks on one power-up. Returns false if the player can't afford it.
    @discardableResult
    public mutating func buy(_ powerUp: PowerUp) -> Bool {
        guard sparks >= powerUp.cost else { return false }
        sparks -= powerUp.cost
        stock[powerUp, default: 0] += 1
        return true
    }
}
