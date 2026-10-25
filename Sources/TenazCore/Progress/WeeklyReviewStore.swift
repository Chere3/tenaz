import Foundation
import GRDB

/// Builds the weekly review from local tables and saves the learner's answers (PLAN F16).
public struct WeeklyReviewStore: Sendable {
    public let database: TenazDatabase
    let calendar: Calendar
    public static let automaticityEveryDays = 14
    public static let maxActivePlans = 3

    public init(database: TenazDatabase, calendar: Calendar = .current) {
        self.database = database
        self.calendar = calendar
    }

    public func report(now: Date, stages: StageConfig) throws -> WeeklyReviewReport {
        let today = DayBoundary.day(for: now, calendar: calendar)
        let weekStart = LearningDays.weekStart(today)
        let from7 = LearningDays.adding(-6, to: today)
        let from30 = LearningDays.adding(-29, to: today)
        let weekStartMs = ProgressDays.startMs(of: from7, calendar: calendar)
        return try database.reader.read { db in
            let qualified = Set(try Int.fetchAll(db, sql: "SELECT day FROM day_stat WHERE qualified = 1 AND day >= ?", arguments: [from30]))
            let last7 = LearningDays.range(from7, through: today).map { WeeklyReviewReport.Day(day: $0, qualified: qualified.contains($0)) }

            let days30 = LearningDays.range(from30, through: today)
            let cards = try Row.fetchAll(db, sql: "SELECT id, noteId, type FROM card").compactMap { row -> (id: String, noteId: String, type: CardType)? in
                guard let type = CardType(rawValue: row["type"]) else { return nil }
                return (row["id"], row["noteId"], type)
            }
            let primary = MasteryHistory.primaryCards(cards)
            let reviews = try Row.fetchAll(db, sql: "SELECT cardId, ts, rating, sAfter FROM review_log ORDER BY ts").map {
                MasteryHistory.Review(cardId: $0["cardId"], ts: $0["ts"], rating: $0["rating"], stability: $0["sAfter"])
            }
            let series = MasteryHistory.series(primary: primary, reviews: reviews,
                                               dayEnds: days30.map { ProgressDays.endMs(of: $0, calendar: calendar) }, config: stages)

            let errors = try ErrorLedgerRecord.fetchAll(db).map { e in
                ErrorTrend(category: e.category, name: QuestGenerator.categoryNames[e.category] ?? e.category, count: e.count,
                           isNew: e.firstSeen >= weekStartMs, activeThisWeek: e.lastSeen >= weekStartMs,
                           example: e.example, correction: e.correction)
            }
            let byCategory = Dictionary(grouping: errors, by: \.category).map { _, rows in
                var top = rows.max { ($0.activeThisWeek ? 1 : 0, $0.count) < ($1.activeThisWeek ? 1 : 0, $1.count) }!
                top.count = rows.reduce(0) { $0 + $1.count }
                top.isNew = rows.allSatisfy(\.isNew)
                top.activeThisWeek = rows.contains(where: \.activeThisWeek)
                return top
            }
            .sorted { ($0.activeThisWeek ? 1 : 0, $0.count, $1.category) > ($1.activeThisWeek ? 1 : 0, $1.count, $0.category) }

            let events = try PenaltyEventRecord.fetchAll(db)
            let suggested = Set(PenaltyExperimentLog.suggestDisable(events, today: today))
            let rules = PenaltyRuleKind.allCases.map { kind in
                RuleWeek(rule: kind.rawValue, stats: PenaltyExperimentLog.stats(events, rule: kind.rawValue, days: from7...today),
                         suggestTurnOff: suggested.contains(kind.rawValue))
            }.filter { $0.stats.shown > 0 }

            // Hatches come from `hatch_event`, which IntrusionCoordinator writes once per use (kill switch,
            // pause, meeting claims, snoozes, skips). `intrusion_log.outcome` says how a surface ended and
            // would over-count: "killed" is also written for a pause and for quitting the app.
            var hatches = HatchCounts()
            let used = try HatchEventRecord.filter(Column("day") >= from7 && Column("day") <= today).fetchAll(db)
            for h in used {
                switch h.kind {
                case .killSwitch: hatches.killSwitch += 1
                case .pause1h: hatches.pause += 1
                case .meetingClaim, .joiningCall:
                    if h.corroborated { hatches.meetingClaims += 1 } else { hatches.uncorroboratedClaims += 1 }
                case .snooze: hatches.snoozes += 1
                case .overlaySkip: hatches.skips += 1
                case .emergencySkip: hatches.emergencySkips += 1
                case .notNow: break
                }
            }
            let claims = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(meetingClaims), 0) FROM day_stat WHERE day >= ?", arguments: [from7]) ?? 0
            hatches.uncorroboratedClaims = max(hatches.uncorroboratedClaims, claims)
            hatches.emergencySkips = max(hatches.emergencySkips, PenaltyExperimentLog.stats(events, rule: PenaltyRuleKind.responseCost.rawValue,
                                                                                           days: from7...today).escaped)

            let lastRated = try WeeklyReviewRecord.filter(Column("automaticity") != nil).order(Column("weekStart").desc).fetchOne(db)
            let due = lastRated.map { LearningDays.distance(from: $0.weekStart, to: weekStart) >= Self.automaticityEveryDays } ?? true

            return WeeklyReviewReport(
                today: today, weekStart: weekStart, last7: last7,
                daysPracticed7: last7.filter(\.qualified).count, daysPracticed30: qualified.count,
                masteredSeries: series, masteredGained7: (series.last ?? 0) - (series.dropLast(7).last ?? 0),
                errors: Array(byCategory.prefix(4)), rules: rules, hatches: hatches,
                automaticityDue: due, lastAutomaticity: lastRated?.automaticity,
                plans: try IfThenPlanRecord.filter(Column("active") == true).order(Column("createdAt").desc).fetchAll(db),
                saved: try WeeklyReviewRecord.filter(Column("weekStart") == weekStart).fetchOne(db))
        }
    }

    /// Saves (or replaces) this week's review and stores a new if-then plan when both parts are
    /// filled; only the newest `maxActivePlans` plans stay active.
    @discardableResult
    public func save(report: WeeklyReviewReport, answers: WeeklyReviewAnswers, automaticity: Int?,
                     plan: (cue: String, action: String)?, now: Date) throws -> WeeklyReviewRecord {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let answersJSON = String(decoding: try encoder.encode(answers), as: UTF8.self)
        let hatchJSON = String(decoding: try encoder.encode(report.hatches), as: UTF8.self)
        let ms = now.unixMilliseconds
        return try database.writer.write { db in
            var record = try WeeklyReviewRecord.filter(Column("weekStart") == report.weekStart).fetchOne(db)
                ?? WeeklyReviewRecord(weekStart: report.weekStart, createdAt: ms, answers: answersJSON, automaticity: nil, hatchCounts: hatchJSON)
            record.createdAt = ms
            record.answers = answersJSON
            record.hatchCounts = hatchJSON
            if let automaticity { record.automaticity = min(7, max(1, automaticity)) }
            try record.save(db)
            if let plan { try Self.insertPlan(db, cue: plan.cue, action: plan.action, ms: ms) }
            return record
        }
    }

    /// Stores one if-then plan (onboarding's first plan and the weekly review's both land in
    /// `if_then_plan`); only the newest `maxActivePlans` stay active. Empty parts store nothing.
    @discardableResult
    public func addPlan(cue: String, action: String, now: Date) throws -> IfThenPlanRecord? {
        try database.writer.write { db in try Self.insertPlan(db, cue: cue, action: action, ms: now.unixMilliseconds) }
    }

    @discardableResult
    static func insertPlan(_ db: Database, cue rawCue: String, action rawAction: String, ms: Int64) throws -> IfThenPlanRecord? {
        let cue = rawCue.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = rawAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cue.isEmpty, !action.isEmpty else { return nil }
        var p = IfThenPlanRecord(cue: cue, action: action, createdAt: ms)
        try p.insert(db)
        let keep = try Int64.fetchAll(db, sql: "SELECT id FROM if_then_plan WHERE active = 1 ORDER BY createdAt DESC, id DESC LIMIT ?",
                                      arguments: [maxActivePlans])
        try db.execute(sql: "UPDATE if_then_plan SET active = 0 WHERE active = 1 AND id NOT IN (\(keep.map(String.init).joined(separator: ",")))")
        return p
    }
}
