import Foundation
import GRDB

/// Where an item was shown (dataset plan §6).
public enum ExposureSurface: String, Codable, Sendable, CaseIterable {
    case gate, write, exam, review
}

/// One item shown on one surface (`exposure` table). Written when the item reaches the screen,
/// not only when it is answered, so every surface can avoid what the learner has already seen.
public struct ExposureRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "exposure"

    public var id: Int64?
    public var itemId: String
    public var groupId: String?
    public var surface: String
    /// The resolved writing kind (`WritingKind` raw value), nil for non-writing items.
    public var kind: String?
    public var ts: Int64

    public init(itemId: String, groupId: String? = nil, surface: ExposureSurface, kind: String? = nil, at date: Date) {
        self.itemId = itemId
        self.groupId = groupId
        self.surface = surface.rawValue
        self.kind = kind
        ts = date.unixMilliseconds
    }

    public init(item: ExamItem, surface: ExposureSurface, at date: Date) {
        self.init(itemId: item.id, groupId: item.group, surface: surface, kind: item.writingKind?.rawValue, at: date)
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

/// v-exposure: the table, its indexes, and a one-time backfill from what was answered before it existed.
enum ExposureSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("exposure_v1") { db in
            try db.create(table: "exposure") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("itemId", .text).notNull()
                t.column("groupId", .text)
                t.column("surface", .text).notNull() // gate / write / exam / review
                t.column("kind", .text)
                t.column("ts", .integer).notNull()
            }
            try db.create(index: "exposure_item", on: "exposure", columns: ["itemId"])
            try db.create(index: "exposure_group", on: "exposure", columns: ["groupId"])
            // Backfill: exam items answered (vocabulary probes are FSRS's business), and gate / Write
            // prompts answered (every one of those was a plain `personal` lifeParagraph).
            try db.execute(sql: """
                INSERT INTO exposure (itemId, groupId, surface, kind, ts)
                SELECT r.itemId, NULL, 'exam', NULL, a.startedAt
                FROM exam_response r JOIN exam_attempt a ON a.id = r.attemptId
                WHERE r.itemId NOT LIKE 'vocab:%'
                """)
            try db.execute(sql: """
                INSERT INTO exposure (itemId, groupId, surface, kind, ts)
                SELECT promptId, NULL, surface, 'personal', ts FROM writing_entry
                WHERE promptId IS NOT NULL AND surface IN ('gate', 'write')
                """)
        }
    }
}

/// Reads and writes the exposure log.
public struct ExposureStore: Sendable {
    public let database: TenazDatabase

    public init(database: TenazDatabase) { self.database = database }

    public func record(_ item: ExamItem, surface: ExposureSurface, at date: Date) throws {
        try record(ExposureRecord(item: item, surface: surface, at: date))
    }

    public func record(_ exposure: ExposureRecord) throws {
        try database.writer.write { db in
            var row = exposure
            try row.insert(db)
        }
    }

    /// Every exposure, oldest first. The table stays small (a few rows a day), and the writing rule
    /// ("never again until 90 % of the pool is used") needs all of it.
    public func all() throws -> [ExposureRecord] {
        try database.reader.read { db in
            try ExposureRecord.order(Column("ts"), Column("id")).fetchAll(db)
        }
    }
}
