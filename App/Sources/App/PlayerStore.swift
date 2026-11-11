import Foundation
import Observation
import TriviaKit

/// App-wide player state: the Sparks wallet, power-up stock, and the
/// question bank. Saved locally for now; moves to iCloud/Game Center later.
@MainActor
@Observable
final class PlayerStore {
    private(set) var wallet: Wallet
    let bank: QuestionBank

    @ObservationIgnored private let defaults: UserDefaults
    private static let walletKey = "wallet.v1"

    init(defaults: UserDefaults = .standard, bank: QuestionBank = PlayerStore.loadBundledBank()) {
        self.defaults = defaults
        self.bank = bank
        if let data = defaults.data(forKey: Self.walletKey),
           let saved = try? JSONDecoder().decode(Wallet.self, from: data) {
            wallet = saved
        } else {
            wallet = .starter
        }
    }

    /// A fresh classic round, optionally limited to one category.
    func newSession(category: String?, relaxed: Bool) -> GameSession {
        let round = bank.dealRound(category: category)
        return GameSession(questions: round.questions, reserve: round.reserve, isTimed: !relaxed)
    }

    /// Uses a power-up if the round rules allow it and the player has one.
    @discardableResult
    func use(_ powerUp: PowerUp, in session: inout GameSession) -> Bool {
        guard wallet.count(of: powerUp) > 0, session.canUse(powerUp) else { return false }
        session.use(powerUp)
        wallet.consume(powerUp)
        save()
        return true
    }

    func award(sparks: Int) {
        wallet.earn(sparks: sparks)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(wallet) {
            defaults.set(data, forKey: Self.walletKey)
        }
    }

    nonisolated static func loadBundledBank() -> QuestionBank {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? QuestionBank(jsonData: data) else {
            return QuestionBank(questions: Question.samples)
        }
        return bank
    }

    static var preview: PlayerStore {
        PlayerStore(defaults: UserDefaults(suiteName: "preview")!)
    }
}
