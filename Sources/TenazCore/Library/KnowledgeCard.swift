import Foundation

/// A "Brain bite" (PLAN F11, research 08 §7): 120-200 words at B1+/B2 on tech, AI, psychology,
/// neuroscience or startups, with 3 target notes from the deck, a question that makes the learner use a
/// word about his own work, and a "go deeper" catalog item. Written for Tenaz (`tenaz-original`).
public struct KnowledgeCard: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    /// TECH, AI, PSY, NEURO or STARTUP.
    public var topic: String
    public var cefr: String
    public var body: String
    /// Vocab ids (`Content/vocab`) that the body uses.
    public var targetNoteIds: [String]
    public var question: String
    /// A `CatalogItem.id`.
    public var goDeeper: String
    public var source: String

    public static let topics: Set<String> = ["TECH", "AI", "PSY", "NEURO", "STARTUP"]
    public static let wordRange = 120...200

    public var wordCount: Int { body.split(whereSeparator: \.isWhitespace).count }

    /// About a minute per 150 words, never less than 1.
    public var readingMinutes: Int { max(1, Int((Double(wordCount) / 150).rounded())) }

    public static func loadAll(from url: URL) throws -> [KnowledgeCard] {
        try JSONDecoder().decode([KnowledgeCard].self, from: Data(contentsOf: url))
    }

    /// Today's card: the unread ones in file order, rotated by the learning day so it is stable for a
    /// day and changes the next; once all are read, the rotation restarts over all cards.
    public static func brainBite(_ cards: [KnowledgeCard], read: Set<String>, day: Int) -> KnowledgeCard? {
        let unread = cards.filter { !read.contains($0.id) }
        let pool = unread.isEmpty ? cards : unread
        guard !pool.isEmpty else { return nil }
        let ordinal = LearningDays.distance(from: 20260101, to: day)
        return pool[((ordinal % pool.count) + pool.count) % pool.count]
    }
}
