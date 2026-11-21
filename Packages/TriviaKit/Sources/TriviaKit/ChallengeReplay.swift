import Foundation

/// One answer in a challenge turn: which choice, how fast, and what it
/// scored. Short coding keys keep a group's long round small in match data.
public struct ChallengePick: Codable, Equatable, Sendable {
    public let questionID: UUID
    /// nil when the clock ran out.
    public let choice: Int?
    /// Seconds the question was showing before the answer.
    public let seconds: Double
    public let correct: Bool
    public let points: Int
    public let powerUp: PowerUp?

    public init(questionID: UUID, choice: Int?, seconds: Double, correct: Bool,
                points: Int, powerUp: PowerUp? = nil) {
        self.questionID = questionID
        self.choice = choice
        // Tenths are plenty for a replay.
        self.seconds = (max(seconds, 0) * 10).rounded() / 10
        self.correct = correct
        self.points = points
        self.powerUp = powerUp
    }

    public init(result: QuestionResult) {
        self.init(questionID: result.question.id, choice: result.choice, seconds: result.answeredAfter,
                  correct: result.correct, points: result.points, powerUp: result.powerUp)
    }

    public var timedOut: Bool { choice == nil }

    private enum CodingKeys: String, CodingKey {
        case questionID = "q", choice = "c", seconds = "s", correct = "ok", points = "p", powerUp = "u"
    }
}

/// A Player Card as other players see it: cosmetic IDs by slot plus the
/// text lines. Unknown IDs (from a newer build) fall back to defaults.
public struct SharedCard: Codable, Equatable, Sendable {
    public var name: String
    public var title: String
    /// Showcase label and value, already worked out ("Best streak", "14").
    public var statLabel: String?
    public var statValue: String?
    /// SF Symbol for the corner (an emblem or a stamp).
    public var corner: String?
    /// Cosmetic ID by `CosmeticSlot.rawValue`, card slots only.
    public var items: [String: String]

    public init(name: String, title: String, statLabel: String? = nil, statValue: String? = nil,
                corner: String? = nil, items: [String: String] = [:]) {
        self.name = String(name.prefix(PlayerCard.maxNameLength))
        self.title = title
        self.statLabel = statLabel
        self.statValue = statValue
        self.corner = corner
        self.items = items
    }

    /// The cosmetic in `slot`, or the default when it's missing or unknown.
    public func item(_ slot: CosmeticSlot) -> Cosmetic {
        items[slot.rawValue].flatMap(CosmeticCatalog.item).flatMap { $0.slot == slot ? $0 : nil }
            ?? CosmeticCatalog.item(CosmeticCatalog.defaults[slot]!)!
    }

    /// Slots that show on a Player Card (not the app theme).
    public static let slots: [CosmeticSlot] = [.avatar, .avatarColor, .border, .cardShape, .cardBackground,
                                               .emblem, .nameStyle, .sticker, .finish]
}

/// What a match knows about one player besides their turn.
public struct ChallengePlayer: Codable, Equatable, Sendable {
    public var card: SharedCard?
    /// The app build (CFBundleVersion) they last opened the match on.
    public var build: Int
    public var version: String?

    public init(card: SharedCard?, build: Int, version: String? = nil) {
        self.card = card
        self.build = build
        self.version = version
    }
}

// MARK: Replay

/// One question of a finished match, with everyone's answer, for the
/// breakdown screen and the live replay.
public struct ReplayQuestion: Identifiable, Equatable, Sendable {
    public struct Answer: Equatable, Sendable {
        public let playerID: String
        /// `pick.choice` is nil when they timed out.
        public let pick: ChallengePick
    }

    public let index: Int
    public let question: Question
    /// In the order they answered, fastest first.
    public let answers: [Answer]
    /// Players whose round ended before this question.
    public let didNotReach: [String]
    /// Players who used Skip on this question (they answered a spare instead).
    public let skipped: [String]
    /// A spare that Skip swapped in for someone.
    public let isSpare: Bool

    public var id: Int { index }

    /// Seconds until the last answer came in, for real-time playback.
    public var duration: Double { answers.map(\.pick.seconds).max() ?? 0 }

    public func answer(for playerID: String) -> Answer? { answers.first { $0.playerID == playerID } }

    /// Players who picked `choice`.
    public func players(choosing choice: Int) -> [String] {
        answers.filter { $0.pick.choice == choice }.map(\.playerID)
    }
}

extension ChallengeData {
    /// Whether this match recorded what each player picked.
    public var hasReplay: Bool { turns.contains { $0.picks?.isEmpty == false } }

    /// Every question anyone answered, in the order it was dealt, with each
    /// player's pick. A player who used Skip answered a spare in that slot
    /// instead; the spare gets its own entry right after the dealt question.
    public func replay(among playerIDs: [String]) -> [ReplayQuestion] {
        let played = turns.filter { playerIDs.contains($0.playerID) && $0.picks != nil }
        let picks = played.map { (id: $0.playerID, picks: $0.picks ?? []) }
        var out: [ReplayQuestion] = []
        var used = Set<UUID>()

        func add(_ question: Question, slot: Int, isSpare: Bool) {
            guard used.insert(question.id).inserted else { return }
            var answers: [ReplayQuestion.Answer] = []
            var notReached: [String] = []
            var skipped: [String] = []
            for player in picks {
                if slot < player.picks.count {
                    let pick = player.picks[slot]
                    if pick.questionID == question.id {
                        answers.append(.init(playerID: player.id, pick: pick))
                    } else if !isSpare {
                        skipped.append(player.id)
                    }
                } else if !isSpare {
                    notReached.append(player.id)
                }
            }
            answers.sort { $0.pick.seconds < $1.pick.seconds }
            out.append(ReplayQuestion(index: out.count, question: question, answers: answers,
                                      didNotReach: notReached, skipped: skipped, isSpare: isSpare))
        }

        let deepest = picks.map(\.picks.count).max() ?? 0
        for slot in 0..<min(deepest, questions.count) {
            add(questions[slot], slot: slot, isSpare: false)
            for player in picks where slot < player.picks.count {
                let id = player.picks[slot].questionID
                if id != questions[slot].id, let spare = question(withID: id) {
                    add(spare, slot: slot, isSpare: true)
                }
            }
        }
        return out
    }
}
