import Foundation
import Testing
@testable import TriviaKit

@Suite struct PowerUpShopTests {
    @Test func packsAndKitAreDiscountedButStillCostMoreThanOne() {
        for p in PowerUp.allCases {
            let pack = PowerUpShop.pack(p)
            #expect(pack.items == [p: PowerUpShop.packSize])
            #expect(pack.price < pack.fullPrice)
            #expect(pack.price > p.cost * (PowerUpShop.packSize - 1))
            #expect(pack.price % 5 == 0)
        }
        #expect(PowerUpShop.kit.items.count == PowerUp.allCases.count)
        #expect(PowerUpShop.kit.price < PowerUpShop.kit.fullPrice)
    }

    @Test func doubleDownCanNeverPayForItself() {
        // Best case: a hard question, answered instantly, on a 5+ streak.
        let best = Scoring.breakdown(timeRemaining: GameRules.questionTime, streak: 5,
                                     powerUp: .doubleDown, difficulty: "hard")
        let extraSparks = Scoring.sparks(forPoints: best.powerUpAdjustment)
        #expect(extraSparks < PowerUp.doubleDown.cost)
    }

    @Test func buyingSpendsSparksAndAddsStock() {
        var wallet = Wallet(sparks: 500)
        let ok = wallet.buy(PowerUpShop.kit)
        #expect(ok)
        #expect(wallet.sparks == 500 - PowerUpShop.kit.price)
        for p in PowerUp.allCases { #expect(wallet.count(of: p) == 1) }
    }

    @Test func cantAffordChangesNothing() {
        var wallet = Wallet(sparks: 10, stock: [.skip: 1])
        #expect(wallet.check(PowerUpShop.pack(.skip)) == .needSparks(PowerUpShop.pack(.skip).price - 10))
        let ok = wallet.buy(PowerUpShop.pack(.skip))
        #expect(!ok)
        #expect(wallet == Wallet(sparks: 10, stock: [.skip: 1]))
    }

    @Test func stockIsCapped() {
        var wallet = Wallet(sparks: 10_000, stock: [.extraTime: PowerUpShop.maxStock - 2])
        #expect(wallet.check(PowerUpShop.pack(.extraTime)) == .full(.extraTime))
        #expect(wallet.check(PowerUpShop.single(.extraTime)) == .ok)
        do { let ok = wallet.buy(.extraTime); #expect(ok) }
        do { let ok = wallet.buy(.extraTime); #expect(ok) }
        do { let ok = wallet.buy(.extraTime); #expect(!ok) }
        #expect(wallet.count(of: .extraTime) == PowerUpShop.maxStock)
        #expect(wallet.check(PowerUpShop.kit) == .full(.extraTime))
    }

    @Test func shopListsCheapestFirst() {
        let costs = PowerUpShop.order.map(\.cost)
        #expect(costs == costs.sorted())
        #expect(Set(PowerUpShop.order) == Set(PowerUp.allCases))
    }
}

@Suite struct SparksBalanceTests {
    /// The summary's "+N Sparks" and the wallet must move by the same amount,
    /// bonuses included.
    @Test func roundRewardsMatchWhatTheWalletGains() {
        var progress = PlayerProgress()
        var wallet = Wallet(sparks: 115)
        let qs = (0..<10).map {
            Question(category: "Science", prompt: "P\($0)", choices: ["A", "B", "C", "D"], correctIndex: 0)
        }
        var s = GameSession(questions: qs)
        for i in 0..<10 { s.answer(i % 3 == 2 ? 1 : 0); s.advance() }
        let rewards = progress.record(s, kind: .daily(Day(year: 2026, month: 11, day: 14)))
        wallet.earn(sparks: rewards.sparks)
        #expect(rewards.sparks == s.sparksEarned + rewards.bonusSparks)
        #expect(wallet.sparks == 115 + rewards.sparks)
    }
}
