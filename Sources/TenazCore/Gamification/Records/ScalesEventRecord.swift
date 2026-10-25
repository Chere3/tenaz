import GRDB

/// One Scales change (earned or spent). The balance is the sum and never goes below 0.
public struct ScalesEventRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "scales_event"

    public var id: Int64?
    public var ts: Int64
    public var amount: Int
    public var source: String
    public var refId: String?

    public init(ts: Int64, amount: Int, source: String, refId: String? = nil) {
        self.ts = ts
        self.amount = amount
        self.source = source
        self.refId = refId
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
