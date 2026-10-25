import GRDB

/// A persistent Claude job (`claude_job`). `status`: queued / running / done / failed.
public struct ClaudeJobRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "claude_job"
    public var id: Int64?
    public var kind: String
    public var attemptId: String?
    public var payload: String
    public var status: String
    public var attempts: Int
    public var nextAttemptAt: Int64
    public var createdAt: Int64
    public var finishedAt: Int64?
    public var result: String?
    public var error: String?

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
