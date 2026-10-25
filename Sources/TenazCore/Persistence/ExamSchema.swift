import GRDB

/// Exams, level estimation and Claude grading tables (PLAN §4.3, F5-F7).
/// `integrity_event` belongs to `IntegritySchema` (Integrity area).
/// Timestamps are Unix milliseconds; `day` is `yyyymmdd` with the 04:00 boundary.
enum ExamSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("exams_v1") { db in
            try db.create(table: "exam_attempt") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("blueprintId", .text).notNull()
                t.column("seed", .integer).notNull()
                t.column("startedAt", .integer).notNull()
                t.column("endedAt", .integer)
                t.column("status", .text).notNull() // running / done / void
                t.column("integrity", .text) // IntegrityLevel raw value; NULL = not verified yet
                t.column("integrityConfirmed", .boolean).notNull().defaults(to: false)
                t.column("integrityJSON", .text)
                t.column("pausedMs", .integer).notNull().defaults(to: 0)
                t.column("routes", .text) // JSON {group: "lower"|"upper"}
                // Sectioned weekly/monthly mocks: attempts of one mock share this id (PLAN F5).
                t.column("mockGroupId", .text).indexed()
                // What a deterministic replay needs to resume after a crash or Tivra quit (F5 step 6):
                // the starting posteriors (5 × 81 doubles, ExamSkill.allCases order) and the excluded item ids.
                t.column("priors", .blob)
                t.column("excluded", .text) // JSON [String]
            }
            try db.create(table: "exam_response") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("attemptId", .text).notNull().indexed().references("exam_attempt", onDelete: .cascade)
                t.column("itemId", .text).notNull()
                t.column("sectionId", .text).notNull()
                t.column("skill", .text).notNull()
                t.column("answer", .text) // ExamAnswer JSON, null = unanswered
                t.column("correct", .boolean)
                t.column("latencyMs", .integer)
                t.column("scoreRaw", .double)
                t.column("scoreMax", .double)
                t.column("scoreSource", .text).notNull() // pending (written mid-exam) / objective / wer / claude / local / void
            }
            try db.create(table: "skill_state") { t in
                t.primaryKey("skill", .text)
                t.column("posterior", .blob).notNull() // 81 little-endian doubles
                t.column("thetaHat", .double).notNull()
                t.column("sd", .double).notNull()
                t.column("updatedAt", .integer).notNull()
            }
            try db.create(table: "band_history") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("day", .integer).notNull()
                t.column("attemptId", .text).indexed()
                t.column("kind", .text).notNull() // exam kind, or "promotion"
                t.column("skill", .text).notNull() // an ExamSkill, "overall" or "public"
                t.column("band", .double).notNull()
                t.column("low", .double).notNull()
                t.column("high", .double).notNull()
                t.column("thetaMean", .double).notNull()
                t.column("sd", .double).notNull()
                t.column("verified", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "writing_entry") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("surface", .text).notNull() // exam / gate / session
                t.column("attemptId", .text).indexed()
                t.column("skill", .text) // writing / speaking
                t.column("promptId", .text)
                t.column("prompt", .text).notNull()
                t.column("text", .text).notNull()
                t.column("wordCount", .integer).notNull()
                t.column("metrics", .text) // TextMetrics JSON
                t.column("localGate", .text)
                t.column("gradeStatus", .text).notNull() // pending / graded / failed / local
                t.column("gradeJSON", .text)
                t.column("rubricVersion", .text)
                t.column("localOnly", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "claude_job") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("kind", .text).notNull()
                t.column("attemptId", .text).indexed()
                t.column("payload", .text).notNull()
                t.column("status", .text).notNull() // queued / running / done / failed
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("nextAttemptAt", .integer).notNull()
                t.column("createdAt", .integer).notNull()
                t.column("finishedAt", .integer)
                t.column("result", .text)
                t.column("error", .text)
            }
            try db.create(table: "grade_run") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("targetKind", .text).notNull()
                t.column("targetId", .integer).notNull()
                t.column("criterion", .text).notNull()
                t.column("score", .double).notNull()
                t.column("evidence", .text) // JSON array of quotes
                t.column("cefr", .text)
                t.column("model", .text).notNull()
                t.column("runIndex", .integer).notNull()
                t.column("rubricVersion", .text).notNull()
                t.column("calibrationVersion", .text).notNull()
            }
            try db.create(index: "grade_run_target", on: "grade_run", columns: ["targetKind", "targetId"])
            try db.create(table: "error_ledger") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("category", .text).notNull()
                t.column("example", .text).notNull()
                t.column("correction", .text).notNull()
                t.column("ruleShort", .text)
                t.column("count", .integer).notNull().defaults(to: 1)
                t.column("firstSeen", .integer).notNull()
                t.column("lastSeen", .integer).notNull()
                t.column("noteId", .text)
                t.uniqueKey(["category", "example"])
            }
        }
        // Resume support for the exam UI (pause between sections, crash recovery, PLAN F5 step 6).
        m.registerMigration("exams_v2_progress") { db in
            try db.create(table: "exam_progress") { t in
                t.primaryKey("attemptId", .text).references("exam_attempt", onDelete: .cascade)
                t.column("sectionIndex", .integer)
                t.column("pausedBetweenSections", .boolean).notNull().defaults(to: false)
                t.column("updatedAt", .integer).notNull()
                t.column("notes", .text) // JSON {taskId: note}
            }
        }
    }
}
