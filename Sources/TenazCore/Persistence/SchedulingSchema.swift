import GRDB

/// v2: notes, cards and the review log (PLAN §4.3, M2).
enum SchedulingSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("v2_scheduling") { db in
            try db.create(table: "note") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("display", .text).notNull()
                t.column("lemma", .text).notNull()
                t.column("glossEs", .text).notNull()
                t.column("exampleEn", .text).notNull()
                t.column("exampleEs", .text).notNull()
                t.column("cefr", .text).notNull()
                t.column("freqRank", .integer)
                t.column("tags", .text).notNull()
                t.column("mustKnow", .boolean).notNull().defaults(to: false)
                t.column("source", .text).notNull()
                t.column("sourceRef", .text).notNull()
                t.column("suspended", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "card") { t in
                t.primaryKey("id", .text)
                t.column("noteId", .text).notNull().indexed().references("note", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("state", .text).notNull()
                t.column("step", .integer)
                t.column("due", .integer).notNull().indexed()
                t.column("stability", .double)
                t.column("difficulty", .double)
                t.column("reps", .integer).notNull().defaults(to: 0)
                t.column("lapses", .integer).notNull().defaults(to: 0)
                t.column("lastReview", .integer)
                t.column("desiredRetention", .double).notNull()
                t.column("leech", .boolean).notNull().defaults(to: false)
                t.column("buriedUntilDay", .integer)
            }
            try db.create(table: "review_log") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cardId", .text).notNull().indexed().references("card", onDelete: .cascade)
                t.column("ts", .integer).notNull().indexed()
                t.column("rating", .integer).notNull()
                t.column("stateBefore", .text).notNull()
                t.column("stateAfter", .text).notNull()
                t.column("sBefore", .double)
                t.column("sAfter", .double)
                t.column("dBefore", .double)
                t.column("dAfter", .double)
                t.column("elapsedDays", .double).notNull()
                t.column("scheduledDays", .double).notNull()
                t.column("durationMs", .integer).notNull()
                t.column("inputMode", .text).notNull()
                t.column("surface", .text).notNull()
                t.column("answerText", .text)
                t.column("appFocusOk", .boolean)
            }
        }
    }
}
