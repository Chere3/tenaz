import GRDB

/// One criterion score from one Claude run (`grade_run`).
public struct GradeRunRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "grade_run"
    public var id: Int64?
    public var ts: Int64
    public var targetKind: String
    public var targetId: Int64
    public var criterion: String
    public var score: Double
    public var evidence: String?
    public var cefr: String?
    public var model: String
    public var runIndex: Int
    public var rubricVersion: String
    public var calibrationVersion: String

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
