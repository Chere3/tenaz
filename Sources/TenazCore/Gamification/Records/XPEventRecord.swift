import GRDB

/// One XP grant. Amounts are never negative, which is why the level can never go down.
public struct XPEventRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "xp_event"

    public var id: Int64?
    public var ts: Int64
    public var day: Int
    public var amount: Int
    public var source: String
    public var refId: String?

    public init(ts: Int64, day: Int, amount: Int, source: String, refId: String?) {
        self.ts = ts
        self.day = day
        self.amount = max(0, amount) // XP is never taken away
        self.source = source
        self.refId = refId
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
