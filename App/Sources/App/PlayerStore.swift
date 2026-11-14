import Foundation
import Observation
import TriviaKit

/// What the player asked to play. Identifiable so it can drive a cover.
struct RoundRequest: Identifiable {
    enum Kind {
        case solo(mode: GameMode, category: String?, difficulty: Difficulty)
        /// The Daily for this date (fixed when the round starts, so a round
        /// that runs past midnight still counts for the day it began).
        case daily(Day)
        case event(WeeklyEvent, week: Int)
    }

    let id = UUID()
    let kind: Kind

    static func classic(category: String?) -> RoundRequest {
        RoundRequest(kind: .solo(mode: .classic, category: category, difficulty: .mixed))
    }

    var isDaily: Bool { if case .daily = kind { true } else { false } }

    var mode: GameMode {
        if case .solo(let mode, _, _) = kind { mode } else { .classic }
    }
}

/// App-wide player state: the Sparks wallet, power-up stock, long-term
/// progress (Daily, mastery, events, cosmetics, Player Card), and the
/// question bank. Saved locally for now; moves to iCloud/Game Center later.
@MainActor
@Observable
final class PlayerStore {
    private(set) var wallet: Wallet
    private(set) var progress: PlayerProgress
    let bank: QuestionBank

    @ObservationIgnored private let defaults: UserDefaults
    /// Every question the player has been shown, oldest first, so rounds
    /// deal unseen questions until a pool is used up, then the oldest.
    @ObservationIgnored private var seen: SeenQuestions
    private static let walletKey = "wallet.v1"
    private static let progressKey = "progress.v1"
    private static let seenKey = "seenQuestions.v1"
    /// Older builds kept only the last 400 prompts here; read once to migrate.
    private static let legacyRecentKey = "recentPrompts.v1"

    init(defaults: UserDefaults = .standard, bank: QuestionBank = PlayerStore.loadBundledBank()) {
        self.defaults = defaults
        self.bank = bank
        if let data = defaults.data(forKey: Self.walletKey),
           let saved = try? JSONDecoder().decode(Wallet.self, from: data) {
            wallet = saved
        } else {
            wallet = .starter
        }
        if let data = defaults.data(forKey: Self.seenKey),
           let saved = try? JSONDecoder().decode(SeenQuestions.self, from: data) {
            seen = saved
        } else {
            seen = SeenQuestions(prompts: defaults.stringArray(forKey: Self.legacyRecentKey) ?? [])
        }
        if let data = defaults.data(forKey: Self.progressKey),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = saved
        } else {
            progress = PlayerProgress()
        }
    }

    // MARK: Today

    /// Read fresh each time so the Daily and event roll over at local midnight.
    var today: Day { Day.today() }
    var currentEvent: WeeklyEvent { WeeklyEvent.event(on: today) }
    var currentEventProgress: EventProgress {
        progress.eventProgress(currentEvent, week: today.weekIndex)
    }
    var todaysDaily: DailyRecord? { progress.dailies[today] }
    var dailyStreak: Int { progress.streak.current(on: today) }

    // MARK: Rounds

    /// Deals the round for a request. Returns nil if today's Daily was
    /// already played (one attempt per day).
    func newSession(for request: RoundRequest, relaxed: Bool) -> GameSession? {
        switch request.kind {
        case .solo(let mode, let category, let difficulty):
            let round = bank.dealRound(count: mode.questionCount, category: category,
                                       difficulty: difficulty.tag, seen: seen)
            // The first few are seen even if the app closes mid-round; the
            // rest are recorded as they're shown (see `finish`).
            remember(round.questions.prefix(GameRules.questionsPerRound))
            return GameSession(questions: round.questions, reserve: round.reserve,
                               isTimed: !(relaxed && mode.supportsRelaxed), mode: mode)
        case .daily(let day):
            guard progress.beginDaily(on: day, relaxed: relaxed) else { return nil }
            saveProgress()
            let round = DailyChallenge.round(for: day, from: bank)
            return GameSession(questions: round.questions, reserve: round.reserve, isTimed: !relaxed)
        case .event(let event, _):
            let round = event.pool(from: bank).dealRound(seen: seen)
            remember(round.questions[...])
            return GameSession(questions: round.questions, reserve: round.reserve, isTimed: !relaxed)
        }
    }

    /// Credits a round (finished, or left early) and pays out its Sparks.
    @discardableResult
    func finish(_ session: GameSession, for request: RoundRequest, finished: Bool = true) -> RoundRewards {
        let kind: RoundKind = switch request.kind {
        case .solo: .solo
        case .daily(let day): .daily(day)
        case .event(let event, let week): .event(event, week: week)
        }
        remember(session.shownQuestions[...])
        let rewards = progress.record(session, kind: kind, finished: finished)
        wallet.earn(sparks: rewards.sparks)
        save()
        saveProgress()
        return rewards
    }

    /// Questions for a new friend challenge. Always timed: relaxed mode is
    /// solo and Daily only, so both players race the same clock.
    func newChallenge() -> ChallengeData {
        let round = bank.dealRound(reserve: GameRules.challengePowerUpsPerRound, seen: seen)
        remember(round.questions[...])
        return ChallengeData(questions: round.questions, reserve: round.reserve)
    }

    private func remember(_ questions: ArraySlice<Question>) {
        seen.markSeen(questions)
        if let data = try? JSONEncoder().encode(seen) {
            defaults.set(data, forKey: Self.seenKey)
        }
        defaults.removeObject(forKey: Self.legacyRecentKey)
    }

    // MARK: Style and Player Card

    @discardableResult
    func buy(_ cosmetic: Cosmetic) -> Bool {
        guard progress.inventory.buy(cosmetic.id, with: &wallet) else { return false }
        progress.inventory.equip(cosmetic.id)
        save()
        saveProgress()
        return true
    }

    func equip(_ cosmetic: Cosmetic) {
        progress.inventory.equip(cosmetic.id)
        saveProgress()
    }

    func updateCard(_ change: (inout PlayerCard) -> Void) {
        change(&progress.card)
        progress.card.name = String(progress.card.name.prefix(PlayerCard.maxNameLength))
        saveProgress()
    }

    // MARK: Question reports

    func report(_ question: Question, reason: QuestionReport.Reason) {
        progress.reports.append(QuestionReport(question: question, reason: reason))
        saveProgress()
    }

    // MARK: Friends

    /// For the multiplayer layer: record a finished friend match.
    @discardableResult
    func recordMatch(_ outcome: MatchOutcome, against friendID: String, name: String) -> [Stamp] {
        let stamps = progress.recordMatch(outcome, against: friendID, name: name)
        saveProgress()
        return stamps
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Self.progressKey)
        }
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

    /// Bundled question files: our own questions (hand-written, then
    /// AI-drafted), then the Open Trivia DB seed (CC BY-SA 4.0, kept in its
    /// own file; see Credits).
    nonisolated static let bundledBankFiles = ["originals", "originals-ai", "opentdb"]

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
