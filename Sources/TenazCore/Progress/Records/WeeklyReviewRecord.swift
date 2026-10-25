import GRDB

/// One saved Sunday review (`weekly_review`), unique per week (Monday `yyyymmdd`).
public struct WeeklyReviewRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "weekly_review"

    public var id: Int64?
    public var weekStart: Int
    public var createdAt: Int64
    /// `WeeklyReviewAnswers` as JSON.
    public var answers: String
    /// 1...7 self-rated automaticity, asked every two weeks (research 01 R16).
    public var automaticity: Int?
    /// `HatchCounts` as JSON.
    public var hatchCounts: String

    public init(weekStart: Int, createdAt: Int64, answers: String, automaticity: Int?, hatchCounts: String) {
        self.weekStart = weekStart
        self.createdAt = createdAt
        self.answers = answers
        self.automaticity = automaticity
        self.hatchCounts = hatchCounts
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
