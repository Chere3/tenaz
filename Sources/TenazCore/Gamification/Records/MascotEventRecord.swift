import GRDB

/// A change to Tena's meters, kept so the UI can explain why she looks the way she does.
public struct MascotEventRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "mascot_event"

    public var id: Int64?
    public var ts: Int64
    public var kind: String
    public var vitalityDelta: Int
    public var spiritDelta: Int

    public init(ts: Int64, kind: String, vitalityDelta: Int, spiritDelta: Int) {
        self.ts = ts
        self.kind = kind
        self.vitalityDelta = vitalityDelta
        self.spiritDelta = spiritDelta
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
