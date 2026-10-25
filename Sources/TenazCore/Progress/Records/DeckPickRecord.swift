import GRDB

/// A note the learner asked to learn next from the reader (`deck_pick`). Every bundled note is already in
/// the deck as a new card; a pick only asks the queue to introduce it first.
public struct DeckPickRecord: Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "deck_pick"

    public var noteId: String
    public var ts: Int64
    /// Where it came from, e.g. "knowledge:kn-latency".
    public var source: String

    public init(noteId: String, ts: Int64, source: String) {
        self.noteId = noteId
        self.ts = ts
        self.source = source
    }
}
