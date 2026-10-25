import GRDB

/// One use of an escape hatch (`hatch_event`), for the weekly review counts (F10, F16).
public struct HatchEventRecord: Codable, Sendable, Equatable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "hatch_event"
    public var id: Int64?
    public var ts: Int64
    public var kind: HatchKind
    public var corroborated: Bool
    public var cost: Int
    public var day: Int

    public init(ts: Int64, kind: HatchKind, corroborated: Bool = false, cost: Int = 0, day: Int) {
        self.ts = ts
        self.kind = kind
        self.corroborated = corroborated
        self.cost = cost
        self.day = day
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
