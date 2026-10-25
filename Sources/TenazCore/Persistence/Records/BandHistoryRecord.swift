import GRDB

/// A band snapshot (`band_history`). `skill` is an ExamSkill raw value, "overall" or "public".
public struct BandHistoryRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "band_history"
    public static let overall = "overall"
    public static let publicBand = "public"

    public var id: Int64?
    public var ts: Int64
    public var day: Int
    public var attemptId: String?
    public var kind: String
    public var skill: String
    public var band: Double
    public var low: Double
    public var high: Double
    public var thetaMean: Double
    public var sd: Double
    public var verified: Bool

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
