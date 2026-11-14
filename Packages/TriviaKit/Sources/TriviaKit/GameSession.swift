import Foundation

/// The outcome of one question.
public struct QuestionResult: Equatable, Sendable {
    public let question: Question
    /// nil when the clock ran out.
    public let choice: Int?
    public let correct: Bool
    /// Seconds left when answered (nil in relaxed mode).
    public let timeRemaining: Double?
    public let powerUp: PowerUp?
    public let breakdown: ScoreBreakdown
    /// Streak after this answer.
    public let streak: Int

    public var points: Int { breakdown.total }
    public var timedOut: Bool { choice == nil }
}

/// Pure game logic for one classic round. Shared by solo and (later)
/// multiplayer modes, and fully unit-testable: the clock only moves when the
/// UI calls `tick(by:)`, so tests drive time directly.
public struct GameSession: Sendable {
    public enum Phase: Equatable, Sendable {
        case asking
        case answered(QuestionResult)
        case finished
    }

    public private(set) var questions: [Question]
    /// Spare questions that `.skip` swaps in.
    public private(set) var reserve: [Question]
    public private(set) var index = 0
    public private(set) var phase: Phase
    /// False in relaxed mode: no clock, no speed bonus.
    public let isTimed: Bool
    public let powerUpLimit: Int
    public let mode: GameMode

    /// Seconds left on this question (Classic and Survival).
    public private(set) var timeRemaining: Double
    /// Seconds left in the whole round (Speed round only).
    public private(set) var roundTimeRemaining: Double?
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    public private(set) var results: [QuestionResult] = []
    /// Choices hidden by 50/50 or by a missed first try.
    public private(set) var eliminated: Set<Int> = []
    public private(set) var powerUpThisQuestion: PowerUp?
    public private(set) var powerUpsUsed = 0
    /// Questions swapped out by Skip. The player still saw them.
    public private(set) var skippedQuestions: [Question] = []

    /// Streak before the last miss, so second chance can restore it.
    private var streakBeforeMiss: Int?

    public init(questions: [Question],
                reserve: [Question] = [],
                isTimed: Bool = true,
                powerUpLimit: Int = GameRules.soloPowerUpsPerRound,
                mode: GameMode = .classic) {
        self.questions = questions
        self.reserve = reserve
        // A Speed round is its clock, so it can't be relaxed.
        self.isTimed = isTimed || mode == .speed
        self.powerUpLimit = powerUpLimit
        self.mode = mode
        self.timeRemaining = GameRules.questionTime
        self.roundTimeRemaining = mode == .speed ? GameMode.speedRoundSeconds : nil
        self.phase = questions.isEmpty ? .finished : .asking
    }

    // MARK: Reading

    public var currentQuestion: Question? {
        phase == .finished ? nil : questions[index]
    }

    /// Every question the player has been shown so far, including skipped
    /// ones. Long rounds deal more than most players reach; only these count
    /// as seen.
    public var shownQuestions: [Question] {
        guard !questions.isEmpty else { return skippedQuestions }
        return Array(questions.prefix(index + 1)) + skippedQuestions
    }

    public var totalPoints: Int { results.reduce(0) { $0 + $1.points } }
    public var correctCount: Int { results.filter(\.correct).count }
    public var sparksEarned: Int { Scoring.sparks(forPoints: totalPoints) }
    public var breakdown: ScoreBreakdown { results.reduce(.zero) { $0 + $1.breakdown } }
    /// Wrong answers and timeouts so far (Survival ends at three).
    public var strikes: Int { results.filter { !$0.correct }.count }
    public var strikesLeft: Int? {
        mode == .survival ? max(GameMode.survivalStrikes - strikes, 0) : nil
    }
    public var isLastQuestion: Bool {
        index == questions.count - 1 || strikesLeft == 0
    }
    /// The per-question clock runs (not in relaxed mode or a Speed round).
    public var hasQuestionClock: Bool { isTimed && mode != .speed }

    // MARK: Playing

    /// Advances the clock. Times out the question when it reaches zero.
    public mutating func tick(by seconds: Double) {
        guard isTimed, phase == .asking else { return }
        if let round = roundTimeRemaining {
            roundTimeRemaining = max(round - seconds, 0)
            // The question on screen when time runs out doesn't count.
            if roundTimeRemaining == 0 { phase = .finished }
            return
        }
        timeRemaining = max(timeRemaining - seconds, 0)
        if timeRemaining == 0 { resolve(choice: nil) }
    }

    public mutating func answer(_ choice: Int) {
        guard phase == .asking,
              let q = currentQuestion,
              q.choices.indices.contains(choice),
              !eliminated.contains(choice) else { return }
        resolve(choice: choice)
    }

    public mutating func advance() {
        guard case .answered = phase else { return }
        streakBeforeMiss = nil
        if index + 1 < questions.count, strikesLeft != 0 {
            index += 1
            startQuestion()
        } else {
            phase = .finished
        }
    }

    // MARK: Power-ups

    public func canUse(_ powerUp: PowerUp) -> Bool {
        guard powerUpThisQuestion == nil, powerUpsUsed < powerUpLimit else { return false }
        switch powerUp {
        case .secondChance:
            // Only after a real miss with time still on the clock.
            guard case .answered(let r) = phase else { return false }
            return !r.correct && !r.timedOut && (!isTimed || timeRemaining > 0)
        case .skip:
            return phase == .asking && !reserve.isEmpty
        case .fiftyFifty:
            return phase == .asking && wrongChoicesLeft.count >= 2
        case .extraTime:
            return phase == .asking && isTimed
        case .doubleDown:
            return phase == .asking
        }
    }

    /// Applies a power-up. Returns false (and changes nothing) if it can't be
    /// used right now. The caller is responsible for taking it out of stock.
    @discardableResult
    public mutating func use(_ powerUp: PowerUp) -> Bool {
        var rng = SystemRandomNumberGenerator()
        return use(powerUp, using: &rng)
    }

    @discardableResult
    public mutating func use(_ powerUp: PowerUp, using rng: inout some RandomNumberGenerator) -> Bool {
        guard canUse(powerUp) else { return false }
        powerUpsUsed += 1
        powerUpThisQuestion = powerUp
        switch powerUp {
        case .fiftyFifty:
            eliminated.formUnion(wrongChoicesLeft.shuffled(using: &rng).prefix(2))
        case .extraTime:
            if let round = roundTimeRemaining {
                roundTimeRemaining = round + GameRules.extraTimeSeconds
            } else {
                timeRemaining += GameRules.extraTimeSeconds
            }
        case .doubleDown:
            break
        case .skip:
            skippedQuestions.append(questions[index])
            questions[index] = reserve.removeFirst()
            startQuestion()
            // A fresh question gets a fresh power-up slot; the round limit
            // still counts the skip.
            powerUpThisQuestion = nil
        case .secondChance:
            guard case .answered(let missed) = phase else { return false }
            results.removeLast()
            if let choice = missed.choice { eliminated.insert(choice) }
            streak = streakBeforeMiss ?? streak
            streakBeforeMiss = nil
            phase = .asking
        }
        return true
    }

    // MARK: Private

    private var wrongChoicesLeft: [Int] {
        guard let q = currentQuestion else { return [] }
        return q.choices.indices.filter { !q.isCorrect($0) && !eliminated.contains($0) }
    }

    private mutating func startQuestion() {
        timeRemaining = GameRules.questionTime
        eliminated = []
        powerUpThisQuestion = nil
        phase = .asking
    }

    private mutating func resolve(choice: Int?) {
        let q = questions[index]
        let correct = choice.map(q.isCorrect) ?? false
        let clock: Double? = hasQuestionClock ? timeRemaining : nil
        let breakdown: ScoreBreakdown
        if correct {
            streak += 1
            bestStreak = max(bestStreak, streak)
            breakdown = Scoring.breakdown(timeRemaining: clock, streak: streak, powerUp: powerUpThisQuestion,
                                          difficulty: q.difficulty)
        } else {
            streakBeforeMiss = streak
            streak = 0
            breakdown = .zero
        }
        let result = QuestionResult(question: q, choice: choice, correct: correct,
                                    timeRemaining: clock, powerUp: powerUpThisQuestion,
                                    breakdown: breakdown, streak: streak)
        results.append(result)
        guard mode == .speed else {
            phase = .answered(result)
            return
        }
        // Speed round: straight on to the next question, no feedback stop.
        streakBeforeMiss = nil
        if index + 1 < questions.count {
            index += 1
            startQuestion()
        } else {
            phase = .finished
        }
    }
}
