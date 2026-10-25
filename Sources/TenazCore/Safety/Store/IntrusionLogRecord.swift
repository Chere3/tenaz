import GRDB

/// One decision or one surface's end (`intrusion_log`).
public struct IntrusionLogRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "intrusion_log"
    public var id: Int64?
    public var ts: Int64
    public var surface: String
    public var trigger: String
    public var decision: String
    public var reason: String?
    public var outcome: String
    public var durationMs: Int?
    public var mode: String?
    public var micHolders: String?
    public var audioOutHolders: String?
    public var assertionHolders: String?
    public var frontmostBundleId: String?
    public var refundedCost: Int?

    public init(ts: Int64, surface: IntrusionSurface, trigger: IntrusionTrigger, decision: String, reason: String?,
                outcome: IntrusionOutcome, durationMs: Int? = nil, mode: OverlayMode? = nil, frontmostBundleId: String? = nil,
                refundedCost: Int? = nil) {
        self.ts = ts
        self.surface = surface.rawValue
        self.trigger = trigger.rawValue
        self.decision = decision
        self.reason = reason
        self.outcome = outcome.rawValue
        self.durationMs = durationMs
        self.mode = mode?.rawValue
        self.frontmostBundleId = frontmostBundleId
        self.refundedCost = refundedCost
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
