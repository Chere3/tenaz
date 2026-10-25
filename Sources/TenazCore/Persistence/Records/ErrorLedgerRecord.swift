import GRDB

/// A recurring language error (`error_ledger`), unique by category + example.
public struct ErrorLedgerRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "error_ledger"
    public var id: Int64?
    public var category: String
    public var example: String
    public var correction: String
    public var ruleShort: String?
    public var count: Int
    public var firstSeen: Int64
    public var lastSeen: Int64
    public var noteId: String?

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
