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
    /// Lowercased prompts of recently dealt questions, newest last, so rounds
    /// don't repeat until the player has seen a good chunk of the bank.
    @ObservationIgnored private var recentPrompts: [String]
    private static let walletKey = "wallet.v1"
    private static let recentKey = "recentPrompts.v1"
    private static let recentLimit = 400

    init(defaults: UserDefaults = .standard, bank: QuestionBank = PlayerStore.loadBundledBank()) {
        self.defaults = defaults
        self.bank = bank
        if let data = defaults.data(forKey: Self.walletKey),
           let saved = try? JSONDecoder().decode(Wallet.self, from: data) {
            wallet = saved
        } else {
            wallet = .starter
        }
        recentPrompts = defaults.stringArray(forKey: Self.recentKey) ?? []
    }

    /// A fresh classic round, optionally limited to one category.
    func newSession(category: String?, relaxed: Bool) -> GameSession {
        let round = deal(category: category, reserve: GameRules.soloPowerUpsPerRound)
        return GameSession(questions: round.questions, reserve: round.reserve, isTimed: !relaxed)
    }

    /// Questions for a new friend challenge. Always timed: relaxed mode is
    /// solo and Daily only, so both players race the same clock.
    func newChallenge() -> ChallengeData {
        let round = deal(category: nil, reserve: GameRules.challengePowerUpsPerRound)
        return ChallengeData(questions: round.questions, reserve: round.reserve)
    }

    private func deal(category: String?, reserve: Int) -> (questions: [Question], reserve: [Question]) {
        let round = bank.dealRound(reserve: reserve, category: category, avoiding: Set(recentPrompts))
        recentPrompts.append(contentsOf: round.questions.map { $0.prompt.lowercased() })
        recentPrompts = Array(recentPrompts.suffix(Self.recentLimit))
        defaults.set(recentPrompts, forKey: Self.recentKey)
        return round
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

    /// Bundled question files: our own reviewed questions, then the Open
    /// Trivia DB seed (CC BY-SA 4.0, kept in its own file; see Credits).
    nonisolated static let bundledBankFiles = ["originals", "opentdb"]

    nonisolated static func loadBundledBank() -> QuestionBank {
        let banks = bundledBankFiles.compactMap { name -> QuestionBank? in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? QuestionBank(jsonData: data)
        }
        let merged = QuestionBank(merging: banks)
        return merged.questions.isEmpty ? QuestionBank(questions: Question.samples) : merged
    }

    static var preview: PlayerStore {
        PlayerStore(defaults: UserDefaults(suiteName: "preview")!)
    }
}
