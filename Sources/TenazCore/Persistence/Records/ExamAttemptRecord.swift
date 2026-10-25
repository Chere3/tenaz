import Foundation
import GRDB

/// One exam sitting (`exam_attempt`). `status`: running / done / void.
public struct ExamAttemptRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "exam_attempt"
    public var id: String
    public var kind: String
    public var blueprintId: String
    public var seed: Int64
    public var startedAt: Int64
    public var endedAt: Int64?
    public var status: String
    public var integrity: String?
    public var integrityConfirmed: Bool
    public var integrityJSON: String?
    public var pausedMs: Int64
    public var routes: String?
    public var mockGroupId: String?
    public var priors: Data?
    public var excluded: String?
}
