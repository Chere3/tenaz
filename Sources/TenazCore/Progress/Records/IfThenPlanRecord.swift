import GRDB

/// An implementation intention ("If I unlock after lunch, then 3 words"), research 01 R4/R25.
public struct IfThenPlanRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "if_then_plan"

    public var id: Int64?
    public var cue: String
    public var action: String
    public var active: Bool
    public var createdAt: Int64

    public init(cue: String, action: String, active: Bool = true, createdAt: Int64) {
        self.cue = cue
        self.action = action
        self.active = active
        self.createdAt = createdAt
    }

    public var sentence: String { "If \(cue), then \(action)." }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
