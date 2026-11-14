import Foundation

/// Something the power-up shop sells for Sparks: one power-up, a pack of
/// the same kind, or a kit with one of each. Packs are a small discount so
/// stocking up is worth it, never a big enough one to feel like a sale.
public struct PowerUpOffer: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case single(PowerUp)
        case pack(PowerUp)
        case kit
    }

    public let kind: Kind
    public let items: [PowerUp: Int]
    public let price: Int

    public var id: String {
        switch kind {
        case .single(let p): "single.\(p.rawValue)"
        case .pack(let p): "pack.\(p.rawValue)"
        case .kit: "kit"
        }
    }

    public var title: String {
        switch kind {
        case .single(let p): p.title
        case .pack(let p): "\(PowerUpShop.packSize) × \(p.title)"
        case .kit: "Starter kit"
        }
    }

    /// What the same items would cost one at a time.
    public var fullPrice: Int { items.reduce(0) { $0 + $1.key.cost * $1.value } }
    public var savings: Int { fullPrice - price }
}

public enum PowerUpShop {
    /// Most of one power-up a player can hold. Keeps stockpiles in check
    /// and fits the tray's single-digit badge.
    public static let maxStock = 9
    public static let packSize = 3
    /// Packs and the kit take this much off, rounded to the nearest 5.
    public static let bundleDiscount = 0.15

    public static func single(_ p: PowerUp) -> PowerUpOffer {
        PowerUpOffer(kind: .single(p), items: [p: 1], price: p.cost)
    }

    public static func pack(_ p: PowerUp) -> PowerUpOffer {
        PowerUpOffer(kind: .pack(p), items: [p: packSize], price: discounted(p.cost * packSize))
    }

    /// One of each power-up.
    public static let kit = PowerUpOffer(
        kind: .kit,
        items: Dictionary(uniqueKeysWithValues: PowerUp.allCases.map { ($0, 1) }),
        price: discounted(PowerUp.allCases.reduce(0) { $0 + $1.cost }))

    /// Shop order: cheapest first, so the list reads as a price ladder.
    public static let order: [PowerUp] = PowerUp.allCases.sorted {
        $0.cost == $1.cost ? $0.rawValue < $1.rawValue : $0.cost < $1.cost
    }

    static func discounted(_ full: Int) -> Int {
        Int((Double(full) * (1 - bundleDiscount) / 5).rounded()) * 5
    }
}

extension Wallet {
    public enum PurchaseCheck: Equatable, Sendable {
        case ok
        case needSparks(Int)
        /// Buying would go over `PowerUpShop.maxStock` of this power-up.
        case full(PowerUp)
    }

    public func check(_ offer: PowerUpOffer) -> PurchaseCheck {
        for p in PowerUp.allCases {
            if let n = offer.items[p], count(of: p) + n > PowerUpShop.maxStock { return .full(p) }
        }
        return sparks >= offer.price ? .ok : .needSparks(offer.price - sparks)
    }

    /// Spends Sparks on an offer. Returns false (and changes nothing) if the
    /// player can't afford it or it would overfill their stock.
    @discardableResult
    public mutating func buy(_ offer: PowerUpOffer) -> Bool {
        guard check(offer) == .ok, spend(offer.price) else { return false }
        for (p, n) in offer.items { add(p, count: n) }
        return true
    }
}
