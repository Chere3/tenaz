import GRDB

/// Intrusion bookkeeping (PLAN §4.3): attribution columns on `intrusion_log` (mode, holders,
/// refunded cost) and the `hatch_event` table that counts every escape hatch.
enum IntrusionSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("v1_intrusions") { db in
            try db.alter(table: "intrusion_log") { t in
                t.add(column: "mode", .text)
                t.add(column: "micHolders", .text)
                t.add(column: "audioOutHolders", .text)
                t.add(column: "assertionHolders", .text)
                t.add(column: "frontmostBundleId", .text)
                t.add(column: "refundedCost", .integer)
            }
            try db.create(index: "intrusion_log_on_surface_ts", on: "intrusion_log", columns: ["surface", "ts"])
            try db.create(table: "hatch_event") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("corroborated", .boolean).notNull().defaults(to: false)
                t.column("cost", .integer).notNull().defaults(to: 0)
                t.column("day", .integer).notNull().indexed()
            }
        }
    }
}
