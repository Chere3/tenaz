import GRDB

/// Registry of every migration, in order. Each area owns one `register` function in its own
/// file (e.g. `SchedulingSchema.register`), so parallel work only adds a line here.
enum Migrations {
    static func migrator() -> DatabaseMigrator {
        var m = DatabaseMigrator()
        #if DEBUG
        m.eraseDatabaseOnSchemaChange = false
        #endif
        BaseSchema.register(&m)
        IntegritySchema.register(&m)
        SchedulingSchema.register(&m)
        GamificationSchema.register(&m)
        ExamSchema.register(&m)
        ProgressSchema.register(&m)
        IntrusionSchema.register(&m)
        ExposureSchema.register(&m)
        return m
    }
}

/// v1: bookkeeping shared by every area.
enum BaseSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("v1_base") { db in
            try db.create(table: "app_meta") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
            try db.create(table: "intrusion_log") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("surface", .text).notNull()
                t.column("trigger", .text).notNull()
                t.column("decision", .text).notNull()
                t.column("reason", .text)
                t.column("outcome", .text).notNull()
                t.column("durationMs", .integer)
            }
        }
    }
}
