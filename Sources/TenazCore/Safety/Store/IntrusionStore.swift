import Foundation
import GRDB

/// Database side of intrusions: the log, caps history, hatch counts, the gate's forgotten words and
/// saving a gate paragraph for Claude to grade later.
public struct IntrusionStore: Sendable {
    public let database: TenazDatabase
    /// Outcomes that mean the surface reached the screen (they count toward the caps).
    public static let reachedScreen: [IntrusionOutcome] = [
        .shown, .completed, .skipped, .snoozed, .timeout, .timeoutIdle, .timeoutAbandoned, .killed,
        .deferredMidway, .deferredMeeting, .meetingClaimUncorroborated, .earlyInput,
    ]
    /// Gates closed this way are re-offered at the next qualifying unlock (they do not use up a slot).
    static let freeRetry: [IntrusionOutcome] = [.timeoutIdle, .deferredMidway, .deferredMeeting]

    public init(database: TenazDatabase) { self.database = database }

    public static func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }

    @discardableResult
    public func log(_ entry: IntrusionLogRecord) throws -> IntrusionLogRecord {
        try database.writer.write { db in
            var e = entry
            try e.insert(db)
            return e
        }
    }

    /// Surfaces of this kind that reached the screen in the last 2 days (enough for day caps and gaps).
    /// A gate closed for free (idle timeout, meeting) does not use up a slot.
    public func history(_ surface: IntrusionSurface, now: Date) throws -> IntrusionHistory {
        let since = Self.ms(now) - 2 * 86_400_000
        var outcomes = Self.reachedScreen.map(\.rawValue)
        if surface == .gate { outcomes.removeAll { Self.freeRetry.map(\.rawValue).contains($0) } }
        // Only the row that ends a surface counts; `shown` rows are written when it appears.
        outcomes.removeAll { $0 == IntrusionOutcome.shown.rawValue }
        let rows = try database.reader.read { db in
            try IntrusionLogRecord
                .filter(Column("surface") == surface.rawValue && Column("ts") >= since && outcomes.contains(Column("outcome")))
                .fetchAll(db)
        }
        return IntrusionHistory(shown: rows.map { Date(timeIntervalSince1970: Double($0.ts) / 1000) })
    }

    public func logHatch(_ kind: HatchKind, corroborated: Bool = false, cost: Int = 0, at now: Date) throws {
        try database.writer.write { db in
            var h = HatchEventRecord(ts: Self.ms(now), kind: kind, corroborated: corroborated, cost: cost, day: DayBoundary.day(for: now))
            try h.insert(db)
        }
    }

    public func hatchCount(_ kind: HatchKind, day: Int) throws -> Int {
        try database.reader.read { db in
            try HatchEventRecord.filter(Column("kind") == kind.rawValue && Column("day") == day).fetchCount(db)
        }
    }

    /// Hatch counts by kind for the learning days in `days` (weekly review, Safety page).
    public func hatchCounts(days: ClosedRange<Int>) throws -> [HatchKind: Int] {
        let rows = try database.reader.read { db in
            try HatchEventRecord.filter(Column("day") >= days.lowerBound && Column("day") <= days.upperBound).fetchAll(db)
        }
        return rows.reduce(into: [:]) { $0[$1.kind, default: 0] += 1 }
    }

    /// Headwords of notes whose cards were answered wrong at least twice today (F1 "the forgotten
    /// word becomes the gate's required chunk"), most-missed first.
    public func forgottenWords(now: Date, limit: Int = 3) throws -> [String] {
        let start = Self.ms(DayBoundary.start(ofDayContaining: now))
        return try database.reader.read { db in
            try String.fetchAll(db, sql: """
                SELECT note.display FROM review_log
                JOIN card ON card.id = review_log.cardId
                JOIN note ON note.id = card.noteId
                WHERE review_log.ts >= ? AND review_log.rating = 1
                GROUP BY note.id HAVING COUNT(*) >= 2
                ORDER BY COUNT(*) DESC, MAX(review_log.ts) DESC LIMIT ?
                """, arguments: [start, limit])
        }
    }

    /// Saves an accepted gate paragraph and queues its Claude grade (F6): the gate never waits on
    /// Claude; `ClaudeJobQueue` grades it later. Returns the writing entry id.
    @discardableResult
    public func saveGateParagraph(prompt: GatePrompt, text: String, checks: GateCheckResult, at now: Date,
                                  queueGrade: Bool = true) throws -> Int64 {
        try database.writer.write { db in
            let ts = Self.ms(now)
            let local = "{\"words\":\(checks.words),\"english\":\(checks.englishConfidence),\"ttr\":\(checks.typeTokenRatio),\"chunk\":\(checks.chunkPresent)}"
            let metrics = try? String(decoding: JSONEncoder().encode(TextMetrics(text: text)), as: UTF8.self)
            var entry = WritingEntryRecord(id: nil, ts: ts, surface: "gate", attemptId: nil, skill: ExamSkill.writing.rawValue,
                                           promptId: prompt.id, prompt: prompt.gradingPrompt, text: text,
                                           wordCount: checks.words, metrics: metrics, localGate: local,
                                           gradeStatus: queueGrade ? "pending" : "local", gradeJSON: nil,
                                           rubricVersion: GradingRubric.version, localOnly: !queueGrade)
            try entry.insert(db)
            guard queueGrade, let id = entry.id else { return entry.id ?? -1 }
            let payload = GradeJobPayload(entryId: id, skill: .writing, kind: .writing, runs: 1, weight: 0.25, typed: true)
            let json = (try? String(decoding: JSONEncoder().encode(payload), as: UTF8.self)) ?? "{}"
            var job = ClaudeJobRecord(id: nil, kind: "grade", attemptId: nil, payload: json, status: "queued", attempts: 0,
                                      nextAttemptAt: ts, createdAt: ts, finishedAt: nil, result: nil, error: nil)
            try job.insert(db)
            return id
        }
    }
}
