import GRDB

/// Tables for XP, streak, mascot, penalties, quests and achievements (PLAN §4.3, M4 + M9).
/// No foreign keys into `card`/`note`: references are plain text ids so this area stays independent.
enum GamificationSchema {
    static func register(_ m: inout DatabaseMigrator) {
        m.registerMigration("v2_gamification") { db in
            try db.create(table: "day_stat") { t in
                t.primaryKey("day", .integer)
                t.column("correctRetrievals", .integer).notNull().defaults(to: 0)
                t.column("reviewsDone", .integer).notNull().defaults(to: 0)
                t.column("productions", .integer).notNull().defaults(to: 0)
                t.column("qualified", .boolean).notNull().defaults(to: false)
                t.column("frozen", .boolean).notNull().defaults(to: false)
                t.column("minutesActive", .integer).notNull().defaults(to: 0)
                t.column("firstActivityAt", .integer)
                t.column("vitalityLost", .integer).notNull().defaults(to: 0)
                t.column("vitalityRegained", .integer).notNull().defaults(to: 0)
                t.column("penaltyEvents", .integer).notNull().defaults(to: 0)
                t.column("penaltyTaskMinutes", .integer).notNull().defaults(to: 0)
                t.column("nightReviews", .integer).notNull().defaults(to: 0)
                t.column("hatchUsed", .boolean).notNull().defaults(to: false)
                t.column("meetingClaims", .integer).notNull().defaults(to: 0)
                t.column("closed", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "xp_event") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull().indexed()
                t.column("day", .integer).notNull()
                t.column("amount", .integer).notNull()
                t.column("source", .text).notNull()
                t.column("refId", .text)
            }
            try db.create(index: "xp_event_day_ref", on: "xp_event", columns: ["day", "refId"])
            try db.create(table: "scales_event") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("amount", .integer).notNull()
                t.column("source", .text).notNull()
                t.column("refId", .text)
            }
            try db.create(table: "mascot_state") { t in
                t.primaryKey("id", .integer)
                t.column("stage", .integer).notNull()
                t.column("stageSince", .integer).notNull()
                t.column("vitality", .integer).notNull()
                t.column("spirit", .integer).notNull()
                t.column("cosmetics", .text).notNull()
                t.column("repairActive", .boolean).notNull().defaults(to: false)
                t.column("repairReviews", .integer).notNull().defaults(to: 0)
                t.column("repairParagraphDone", .boolean).notNull().defaults(to: false)
                t.column("healedAt", .integer)
                t.column("installedDay", .integer).notNull()
                t.column("lastSettledDay", .integer).notNull()
                t.column("combo", .integer).notNull().defaults(to: 0)
                t.column("bestCombo", .integer).notNull().defaults(to: 0)
                t.column("questMultiplier", .double).notNull().defaults(to: 1.0)
                t.column("flyMentioned", .boolean).notNull().defaults(to: false)
                t.column("masteredHighWater", .integer).notNull().defaults(to: 0)
                t.column("lastWelcomeBackDay", .integer)
            }
            try db.create(table: "mascot_event") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull().indexed()
                t.column("kind", .text).notNull()
                t.column("vitalityDelta", .integer).notNull()
                t.column("spiritDelta", .integer).notNull()
            }
            try db.create(table: "penalty_rule") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("kind", .text).notNull()
                t.column("enabled", .boolean).notNull()
                t.column("params", .text).notNull().defaults(to: "{}")
                t.column("createdAt", .integer).notNull()
                t.column("effectiveAt", .integer).notNull()
                t.column("direction", .text).notNull()
                t.column("pendingCancelled", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "penalty_event") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ruleId", .text).notNull()
                t.column("ts", .integer).notNull().indexed()
                t.column("day", .integer).notNull()
                t.column("cost", .text).notNull()
                t.column("vitality", .integer).notNull().defaults(to: 0)
                t.column("scales", .integer).notNull().defaults(to: 0)
                t.column("mercyUsed", .boolean).notNull().defaults(to: false)
                t.column("task", .text)
                t.column("outcome", .text).notNull()
                t.column("cleared", .boolean).notNull().defaults(to: false)
                t.column("clearedAt", .integer)
                t.column("ledToSession", .boolean).notNull().defaults(to: false)
                t.column("refunded", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "achievement") { t in
                t.primaryKey("id", .text)
                t.column("unlockedAt", .integer)
                t.column("progress", .double).notNull().defaults(to: 0)
            }
            try db.create(table: "quest") { t in
                t.primaryKey("id", .text)
                t.column("day", .integer).notNull().indexed()
                t.column("slot", .text).notNull()
                t.column("template", .text).notNull()
                t.column("title", .text).notNull()
                t.column("metric", .text).notNull()
                t.column("target", .integer).notNull()
                t.column("progress", .integer).notNull().defaults(to: 0)
                t.column("done", .boolean).notNull().defaults(to: false)
                t.column("rewardXP", .integer).notNull()
                t.column("rewardScales", .integer).notNull()
                t.column("mysteryDrop", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "exam_outcome") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ts", .integer).notNull()
                t.column("kind", .text).notNull()
                t.column("band", .double).notNull()
                t.column("bestSectionBand", .double).notNull()
                t.column("integrity", .text).notNull()
                t.column("refId", .text)
            }
        }
    }
}
