import GRDB

/// One contract change. Rows are append-only: the rule in force for a kind at time t is the latest
/// non-cancelled row whose `effectiveAt <= t`. No row means the rule is off.
public struct PenaltyRuleRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "penalty_rule"

    public var id: Int64?
    public var kind: PenaltyRuleKind
    public var enabled: Bool
    public var params = "{}"
    public var createdAt: Int64
    public var effectiveAt: Int64
    public var direction: ChangeDirection
    /// Cancelled before it took effect (one-click cancel, or replaced by a newer change).
    public var pendingCancelled = false

    public init(kind: PenaltyRuleKind, enabled: Bool, params: String = "{}", createdAt: Int64, effectiveAt: Int64,
                direction: ChangeDirection) {
        self.kind = kind
        self.enabled = enabled
        self.params = params
        self.createdAt = createdAt
        self.effectiveAt = effectiveAt
        self.direction = direction
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
