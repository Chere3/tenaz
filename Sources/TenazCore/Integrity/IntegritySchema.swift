import GRDB

enum IntegritySchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("v_integrity_event") { db in
            try db.create(table: "integrity_event") { t in
                t.autoIncrementedPrimaryKey("id")
                // No foreign key: `exam_attempt` is owned by the exams area and may use any id type.
                t.column("attemptId", .text).notNull().indexed()
                t.column("ts", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("detail", .text)
                t.column("durationMs", .integer)
            }
        }
    }
}
