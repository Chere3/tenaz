import GRDB

/// One time a rule fired (or was waived), with its experiment-log outcome.
public struct PenaltyEventRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "penalty_event"

    public var id: Int64?
    /// The `PenaltyRuleKind` raw value that fired.
    public var ruleId: String
    public var ts: Int64
    public var day: Int
    /// The `PenaltyCost` raw value.
    public var cost: String
    public var vitality = 0
    public var scales = 0
    public var mercyUsed = false
    /// A penalty task assigned by this event (`repair`, `extraCards`), if any.
    public var task: String?
    public var outcome: PenaltyOutcome
    public var cleared = false
    public var clearedAt: Int64?
    public var ledToSession = false
    /// Given back (a meeting corroborated the claim later, or a meeting closed the surface).
    public var refunded = false

    public init(ruleId: String, ts: Int64, day: Int, cost: String, outcome: PenaltyOutcome) {
        self.ruleId = ruleId
        self.ts = ts
        self.day = day
        self.cost = cost
        self.outcome = outcome
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
