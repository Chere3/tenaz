import GRDB

/// What gamification remembers about a finished exam (the exam area owns the full attempt).
public struct ExamOutcomeRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "exam_outcome"

    public var id: Int64?
    public var ts: Int64
    public var kind: ExamCreditKind
    public var band: Double
    public var bestSectionBand: Double
    public var integrity: ExamIntegrity
    public var refId: String?

    public init(ts: Int64, outcome: ExamCredit) {
        self.ts = ts
        kind = outcome.kind
        band = outcome.band
        bestSectionBand = outcome.sectionBands.max() ?? outcome.band
        integrity = outcome.integrity
        refId = outcome.attemptId
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
