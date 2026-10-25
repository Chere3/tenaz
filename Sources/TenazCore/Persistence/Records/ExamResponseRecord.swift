import GRDB

/// One answered (or unanswered) task of an attempt (`exam_response`).
public struct ExamResponseRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "exam_response"
    public var id: Int64?
    public var attemptId: String
    public var itemId: String
    public var sectionId: String
    public var skill: String
    public var answer: String?
    public var correct: Bool?
    public var latencyMs: Int64?
    public var scoreRaw: Double?
    public var scoreMax: Double?
    public var scoreSource: String

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
