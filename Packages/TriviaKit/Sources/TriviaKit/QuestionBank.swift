import Foundation

/// A pool of questions to deal rounds from.
///
/// Our own bank: seeded from the Open Trivia Database (CC BY-SA 4.0, kept in
/// its own file and credited in the app) plus our own reviewed questions.
/// Bundled for now; a backend can serve updates later.
public struct QuestionBank: Sendable {
    public let questions: [Question]

    public init(questions: [Question]) {
        self.questions = questions
    }

    public init(jsonData: Data) throws {
        self.questions = try JSONDecoder().decode([Question].self, from: jsonData)
    }

    /// Combines banks, dropping repeated prompts.
    public init(merging banks: [QuestionBank]) {
        var seen = Set<String>()
        self.questions = banks.flatMap(\.questions).filter { seen.insert($0.prompt.lowercased()).inserted }
    }

    /// The order categories appear on Home. Anything else follows, A to Z.
    public static let preferredCategoryOrder = [
        "General", "Science", "History", "Geography", "Movies", "TV", "Music",
        "Sports", "Games", "Books", "Art", "Nature", "Tech", "Pop Culture",
    ]

    public var categories: [String] {
        let present = Set(questions.map(\.category))
        let preferred = Self.preferredCategoryOrder.filter(present.contains)
        return preferred + present.subtracting(preferred).sorted()
    }

    public func count(in category: String) -> Int {
        questions.lazy.filter { $0.category == category }.count
    }

    /// Deals a round: `count` questions plus `reserve` spares for Skip, all
    /// distinct, with answer order shuffled. Questions whose prompt is in
    /// `recent` (lowercased) are used only if there aren't enough fresh ones.
    /// Returns fewer if the pool is small.
    public func dealRound(count: Int = GameRules.questionsPerRound,
                          reserve: Int = GameRules.soloPowerUpsPerRound,
                          category: String? = nil,
                          difficulty: String? = nil,
                          avoiding recent: Set<String> = [],
                          using rng: inout some RandomNumberGenerator) -> (questions: [Question], reserve: [Question]) {
        deal(count: count, reserve: reserve, category: category, difficulty: difficulty,
             age: { recent.contains($0.prompt.lowercased()) ? 0 : nil }, using: &rng)
    }

    /// Deals a round that never repeats a question while unseen ones remain
    /// in the pool. When the pool runs out, the questions seen longest ago
    /// are reused first.
    public func dealRound(count: Int = GameRules.questionsPerRound,
                          reserve: Int = GameRules.soloPowerUpsPerRound,
                          category: String? = nil,
                          difficulty: String? = nil,
                          seen: SeenQuestions,
                          using rng: inout some RandomNumberGenerator) -> (questions: [Question], reserve: [Question]) {
        deal(count: count, reserve: reserve, category: category, difficulty: difficulty,
             age: seen.age(of:), using: &rng)
    }

    public func dealRound(count: Int = GameRules.questionsPerRound,
                          reserve: Int = GameRules.soloPowerUpsPerRound,
                          category: String? = nil,
                          difficulty: String? = nil,
                          seen: SeenQuestions) -> (questions: [Question], reserve: [Question]) {
        var rng = SystemRandomNumberGenerator()
        return dealRound(count: count, reserve: reserve, category: category, difficulty: difficulty,
                         seen: seen, using: &rng)
    }

    /// `age` is nil for an unseen question, else smaller for older sightings.
    private func deal(count: Int, reserve: Int, category: String?, difficulty: String?,
                      age: (Question) -> Int?,
                      using rng: inout some RandomNumberGenerator) -> (questions: [Question], reserve: [Question]) {
        let take = count + reserve
        var eligible = questions.filter { category == nil || $0.category == category }
        if let difficulty {
            let tagged = eligible.filter { $0.difficulty == difficulty }
            // A tiny pool (e.g. a category with few hard ones) falls back to all.
            if tagged.count >= take || tagged.count >= GameRules.questionsPerRound { eligible = tagged }
        }
        var fresh: [Question] = []
        var stale: [(age: Int, q: Question)] = []
        for q in eligible {
            if let a = age(q) { stale.append((a, q)) } else { fresh.append(q) }
        }
        fresh.shuffle(using: &rng)
        // Oldest first; shuffle first so equal ages come out in random order.
        stale.shuffle(using: &rng)
        let reused = stale.sorted { $0.age < $1.age }.map(\.q)
        // Caps only reorder within the fresh questions, so a cap never pulls
        // a repeat in ahead of an unseen question.
        let caps = (maxPerCategory: category == nil ? Self.maxPerCategoryInMix : nil,
                    maxHard: difficulty == nil ? Self.maxHardPerRound : nil)
        var ordered = Self.balanced(fresh, take: take, maxPerCategory: caps.maxPerCategory,
                                    maxHard: caps.maxHard, scaleFor: take)
        if ordered.count < take {
            ordered += Self.balanced(reused, take: take - ordered.count,
                                     maxPerCategory: caps.maxPerCategory, maxHard: caps.maxHard,
                                     scaleFor: take)
        }
        let picked = ordered.map { $0.shufflingChoices(using: &rng) }
        let main = Array(picked.prefix(count))
        let spare = Array(picked.dropFirst(main.count))
        return (main, spare)
    }

    /// A mixed round shows at most this many questions from one category, so
    /// big categories (the seed has lots of video game questions) don't dominate.
    public static let maxPerCategoryInMix = 2
    /// At most this many "hard" questions per round.
    public static let maxHardPerRound = 3

    /// Takes questions in order, skipping ones that would break the category
    /// or difficulty caps; if that leaves too few, fills up with the skipped ones.
    static func balanced(_ candidates: [Question], take: Int, maxPerCategory: Int?,
                         maxHard: Int? = maxHardPerRound, scaleFor roundSize: Int? = nil) -> [Question] {
        // Long rounds (Survival, Speed) scale the caps with their length.
        let scale = max(1, (roundSize ?? take) / (GameRules.questionsPerRound + GameRules.soloPowerUpsPerRound))
        let maxPerCategory = maxPerCategory.map { $0 * scale }
        let maxHard = maxHard.map { $0 * scale }
        var picked: [Question] = []
        var skipped: [Question] = []
        var perCategory: [String: Int] = [:]
        var hard = 0
        for q in candidates {
            guard picked.count < take else { break }
            let isHard = q.difficulty == "hard"
            if let maxPerCategory, perCategory[q.category, default: 0] >= maxPerCategory {
                skipped.append(q); continue
            }
            if isHard, let maxHard, hard >= maxHard {
                skipped.append(q); continue
            }
            picked.append(q)
            perCategory[q.category, default: 0] += 1
            if isHard { hard += 1 }
        }
        if picked.count < take {
            picked += skipped.prefix(take - picked.count)
        }
        return picked
    }

    public func dealRound(count: Int = GameRules.questionsPerRound,
                          reserve: Int = GameRules.soloPowerUpsPerRound,
                          category: String? = nil,
                          difficulty: String? = nil,
                          avoiding recent: Set<String> = []) -> (questions: [Question], reserve: [Question]) {
        var rng = SystemRandomNumberGenerator()
        return dealRound(count: count, reserve: reserve, category: category, difficulty: difficulty,
                         avoiding: recent, using: &rng)
    }
}
