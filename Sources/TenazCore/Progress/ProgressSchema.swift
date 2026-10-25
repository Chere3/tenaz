import GRDB

/// Tables for the Library (F11) and the weekly review (F16): reading log, library status, weekly
/// reviews, if-then plans and "learn this next" deck picks. Every table and index uses
/// `IF NOT EXISTS`, so an area that already created one of them (onboarding's if-then plan) merges
/// without a schema clash.
enum ProgressSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("progress_v1") { db in
            try db.create(table: "reading_log", options: .ifNotExists) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("day", .integer).notNull()
                t.column("itemId", .text).notNull()
                t.column("minutes", .integer).notNull()
                t.column("pages", .integer)
                t.column("words", .integer)
                t.column("wpm", .double)
                t.column("comprehension", .double)
                t.column("note", .text)
            }
            try db.create(index: "reading_log_item", on: "reading_log", columns: ["itemId", "ts"], options: .ifNotExists)
            try db.create(table: "library_item", options: .ifNotExists) { t in
                t.primaryKey("itemId", .text)
                t.column("status", .text).notNull()
                t.column("startedAt", .integer).notNull()
                t.column("updatedAt", .integer).notNull()
                t.column("finishedAt", .integer)
                t.column("abandonReason", .text)
            }
            try db.create(table: "weekly_review", options: .ifNotExists) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("weekStart", .integer).notNull().unique()
                t.column("createdAt", .integer).notNull()
                t.column("answers", .text).notNull()
                t.column("automaticity", .integer)
                t.column("hatchCounts", .text).notNull()
            }
            try db.create(table: "if_then_plan", options: .ifNotExists) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cue", .text).notNull()
                t.column("action", .text).notNull()
                t.column("active", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .integer).notNull()
            }
            try db.create(table: "deck_pick", options: .ifNotExists) { t in
                t.primaryKey("noteId", .text)
                t.column("ts", .integer).notNull()
                t.column("source", .text).notNull()
            }
        }
    }
}
