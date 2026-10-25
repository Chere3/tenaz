import Foundation

/// One book, podcast or video channel in `Content/catalog.json` (PLAN F11, research 08 §2-§3).
/// Metadata only; no text is bundled. Levels and lengths are editorial estimates until the coverage
/// tool measures them (`estimated`).
public struct CatalogItem: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case book, podcast, video
    }

    /// Lane A: graded or plain text for fluency (~98% known). Lane B: authentic stretch (~95%).
    public enum Lane: String, Codable, Sendable {
        case a = "A", b = "B"
    }

    public var id: String
    public var kind: Kind
    public var title: String
    public var creator: String
    /// Canonical CEFR label (A2...C2) used for scoring.
    public var cefr: String
    /// The honest range shown to the learner, e.g. "B2+/C1-".
    public var levelText: String
    public var lane: Lane
    /// Interest tags: TECH, AI, STARTUP, PSY, NEURO, SF, GAMES, SCI, BIO, WORK, MEETINGS, ...
    public var topics: [String]
    /// Books: estimated total words.
    public var words: Int?
    /// Podcasts and videos: typical minutes per episode.
    public var minutes: Int?
    public var series: String?
    public var url: String?
    public var hasTranscript: Bool?
    /// Why it fits the learner, one line.
    public var why: String
    public var estimated: Bool

    public var level: CEFRLevel { CEFRLevel(label: cefr) ?? .b2 }

    public static func loadAll(from url: URL) throws -> [CatalogItem] {
        try JSONDecoder().decode([CatalogItem].self, from: Data(contentsOf: url))
    }
}
