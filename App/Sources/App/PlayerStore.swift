import Foundation
import Observation
import TriviaKit

/// What the player asked to play. Identifiable so it can drive a cover.
struct RoundRequest: Identifiable {
    enum Kind {
        /// `categories` empty means a mixed round.
        case solo(mode: GameMode, categories: [String], difficulty: Difficulty)
        /// The Daily for this date (fixed when the round starts, so a round
        /// that runs past midnight still counts for the day it began).
        case daily(Day)
        case event(WeeklyEvent, week: Int)
    }

    let id = UUID()
    let kind: Kind

    static func classic(categories: [String] = []) -> RoundRequest {
        RoundRequest(kind: .solo(mode: .classic, categories: categories, difficulty: .mixed))
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
    @ObservationIgnored private var eventPools: [String: QuestionBank] = [:]
    /// Called after a solo, Daily or event round is credited, so Game
    /// Center can post the new scores to friends' leaderboards.
    @ObservationIgnored var onRoundRecorded: (@MainActor (RoundKind) -> Void)?
    private static let walletKey = "wallet.v1"
    private static let progressKey = "progress.v1"
    private static let seenKey = "seenQuestions.v1"
    /// Older builds kept only the last 400 prompts here; read once to migrate.
    private static let legacyRecentKey = "recentPrompts.v1"

    init(defaults: UserDefaults = .standard, bank: QuestionBank = PlayerStore.loadBundledBank()) {
        self.defaults = defaults
        self.bank = bank
        wallet = defaults.decoded(Wallet.self, forKey: Self.walletKey) ?? .starter
        progress = defaults.decoded(PlayerProgress.self, forKey: Self.progressKey) ?? PlayerProgress()
        if let saved = defaults.decoded(SeenQuestions.self, forKey: Self.seenKey) {
            seen = saved
        } else {
            // One-time move from the old recent-prompts list.
            let migrated = SeenQuestions(prompts: defaults.stringArray(forKey: Self.legacyRecentKey) ?? [])
            defaults.setEncoded(migrated, forKey: Self.seenKey)
            defaults.removeObject(forKey: Self.legacyRecentKey)
            seen = migrated
        }
        applyTheme()
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
        case .solo(let mode, let categories, let difficulty):
            let round = bank.dealRound(count: mode.questionCount, categories: Set(categories),
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
            let round = eventPool(event).dealRound(seen: seen)
            remember(round.questions[...])
            return GameSession(questions: round.questions, reserve: round.reserve, isTimed: !relaxed)
        }
    }

    /// An event's questions, matched against the whole bank once per run
    /// of the app instead of once per round.
    private func eventPool(_ event: WeeklyEvent) -> QuestionBank {
        if let cached = eventPools[event.id] { return cached }
        let pool = event.pool(from: bank)
        eventPools[event.id] = pool
        return pool
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
        saveWallet()
        saveProgress()
        onRoundRecorded?(kind)
        return rewards
    }

    /// Questions for a new friend challenge, under the rules the challenger
    /// picked. Both players get exactly these.
    func newChallenge(_ setup: ChallengeSetup = .standard) -> ChallengeData {
        let setup = setup.sanitized()
        let round = bank.dealRound(count: setup.questionCount, reserve: setup.reserveCount,
                                   categories: Set(setup.categories), difficulty: setup.difficulty.tag, seen: seen)
        remember(round.questions.prefix(GameRules.questionsPerRound))
        return ChallengeData(setup: setup, questions: round.questions, reserve: round.reserve)
    }

    /// Marks a played challenge's questions as seen. Long rounds deal more
    /// than most players reach, so only the ones shown count.
    func finishChallenge(_ session: GameSession) {
        remember(session.shownQuestions[...])
    }

    private func remember(_ questions: ArraySlice<Question>) {
        seen.markSeen(questions)
        defaults.setEncoded(seen, forKey: Self.seenKey)
    }

    // MARK: Style and Player Card

    @discardableResult
    func buy(_ cosmetic: Cosmetic) -> Bool {
        guard progress.inventory.buy(cosmetic.id, with: &wallet) else { return false }
        progress.inventory.equip(cosmetic.id)
        SoundEffects.shared.play(.purchase)
        saveWallet()
        saveProgress()
        applyTheme()
        return true
    }

    func equip(_ cosmetic: Cosmetic) {
        progress.inventory.equip(cosmetic.id)
        saveProgress()
        applyTheme()
    }

    /// Points the app's colors, background and sounds at what's equipped.
    private func applyTheme() {
        ThemeManager.shared.apply(progress.inventory.equipped(.theme).id)
        SoundEffects.shared.use(progress.inventory.equipped(.sounds).id)
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

    func clearReports() {
        progress.reports.removeAll()
        saveProgress()
    }

    // MARK: Friends

    /// For the multiplayer layer: record a finished friend match. Each
    /// match ID counts once, however often Game Center reports it.
    func recordMatch(_ outcome: ChallengeOutcome, against friendID: String, name: String,
                     matchID: String, at date: Date) {
        guard progress.recordMatch(outcome, against: friendID, name: name, matchID: matchID, at: date) != nil else { return }
        saveProgress()
    }

    /// Carries over which matches older builds already counted.
    func markMatchesCounted(_ matchIDs: Set<String>) {
        progress.rivals.markCounted(matchIDs)
        saveProgress()
    }

    private func saveProgress() {
        defaults.setEncoded(progress, forKey: Self.progressKey)
    }

    /// Uses a power-up if the round rules allow it and the player has one.
    @discardableResult
    func use(_ powerUp: PowerUp, in session: inout GameSession) -> Bool {
        guard wallet.count(of: powerUp) > 0, session.canUse(powerUp) else { return false }
        session.use(powerUp)
        wallet.consume(powerUp)
        saveWallet()
        return true
    }

    /// Buys power-ups from the shop. Returns false if the player can't
    /// afford the offer or it would go over the stock limit.
    @discardableResult
    func buy(_ offer: PowerUpOffer) -> Bool {
        guard wallet.buy(offer) else { return false }
        saveWallet()
        return true
    }

    func award(sparks: Int) {
        wallet.earn(sparks: sparks)
        saveWallet()
    }

    private func saveWallet() {
        defaults.setEncoded(wallet, forKey: Self.walletKey)
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
