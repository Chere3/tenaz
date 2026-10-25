import GRDB

/// Free text the learner wrote (exam writing, typed speaking, later the gate) (`writing_entry`).
/// `gradeStatus`: pending / graded / failed / local.
public struct WritingEntryRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "writing_entry"
    public var id: Int64?
    public var ts: Int64
    public var surface: String
    public var attemptId: String?
    public var skill: String?
    public var promptId: String?
    public var prompt: String
    public var text: String
    public var wordCount: Int
    public var metrics: String?
    public var localGate: String?
    public var gradeStatus: String
    public var gradeJSON: String?
    public var rubricVersion: String?
    public var localOnly: Bool

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
