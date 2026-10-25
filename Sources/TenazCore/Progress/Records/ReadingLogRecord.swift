import GRDB

/// One reading or listening session (`reading_log`), or a Brain bite read (`itemId` "knowledge:<id>").
/// `wpm` is stored only when comprehension is at least 70% (research 08 §1.2).
public struct ReadingLogRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "reading_log"
    public static let knowledgePrefix = "knowledge:"

    public var id: Int64?
    public var ts: Int64
    public var day: Int
    public var itemId: String
    public var minutes: Int
    public var pages: Int?
    public var words: Int?
    public var wpm: Double?
    /// 0...1 from the 3-question self-check.
    public var comprehension: Double?
    /// The Brain bite answer sentence, or a free note.
    public var note: String?

    public init(ts: Int64, day: Int, itemId: String, minutes: Int, pages: Int? = nil, words: Int? = nil,
                wpm: Double? = nil, comprehension: Double? = nil, note: String? = nil) {
        self.ts = ts
        self.day = day
        self.itemId = itemId
        self.minutes = minutes
        self.pages = pages
        self.words = words
        self.wpm = wpm
        self.comprehension = comprehension
        self.note = note
    }

    public var knowledgeCardId: String? {
        itemId.hasPrefix(Self.knowledgePrefix) ? String(itemId.dropFirst(Self.knowledgePrefix.count)) : nil
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
