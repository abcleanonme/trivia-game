import Foundation

/// Which questions a player has already been shown, oldest first, keyed by
/// lowercased prompt (stable across app updates, unlike load-time ids).
///
/// Rounds deal unseen questions first. Once a pool is used up, the questions
/// seen longest ago come back first, so a repeat is always the one you're
/// least likely to remember.
public struct SeenQuestions: Codable, Equatable, Sendable {
    /// Big enough to remember the whole bundled bank several times over.
    public static let defaultLimit = 20_000

    public private(set) var prompts: [String] = []
    public let limit: Int

    public init(prompts: [String] = [], limit: Int = defaultLimit) {
        self.limit = limit
        for p in prompts { markSeen(prompt: p) }
    }

    public var count: Int { prompts.count }

    public func contains(_ question: Question) -> Bool { order[Self.key(question.prompt)] != nil }

    /// 0 for the question seen longest ago; nil if never seen.
    public func age(of question: Question) -> Int? { order[Self.key(question.prompt)] }

    public mutating func markSeen<S: Sequence>(_ questions: S) where S.Element == Question {
        for q in questions { markSeen(prompt: q.prompt) }
    }

    public mutating func markSeen(prompt: String) {
        let key = Self.key(prompt)
        if let i = order[key] {
            prompts.remove(at: i)
            // Everything after `i` moved down one.
            for j in i..<prompts.count { order[prompts[j]] = j }
        }
        prompts.append(key)
        order[key] = prompts.count - 1
        if prompts.count > limit {
            let drop = prompts.count - limit
            prompts.removeFirst(drop)
            order = Self.index(prompts)
        }
    }

    static func key(_ prompt: String) -> String { prompt.lowercased() }

    // MARK: Storage

    private var order: [String: Int] = [:]

    private static func index(_ prompts: [String]) -> [String: Int] {
        Dictionary(prompts.enumerated().map { ($1, $0) }, uniquingKeysWith: { _, new in new })
    }

    enum CodingKeys: String, CodingKey { case prompts, limit }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? Self.defaultLimit
        self.init(prompts: try c.decode([String].self, forKey: .prompts), limit: limit)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(prompts, forKey: .prompts)
        try c.encode(limit, forKey: .limit)
    }

    public static func == (a: Self, b: Self) -> Bool { a.prompts == b.prompts && a.limit == b.limit }
}
