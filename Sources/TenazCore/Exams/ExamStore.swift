import Foundation
import GRDB

/// Persistence for exams, skill states, bands, writing entries and grading jobs.
/// Writes go through the database writer; every multi-row change is one transaction.
public struct ExamStore: Sendable {
    public let database: TenazDatabase

    public init(database: TenazDatabase) { self.database = database }

    static func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }
    static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }

    // MARK: Skill states

    /// Stored posteriors; skills never estimated get the default prior N(-0.3, 1) (B1+).
    public func skillStates() throws -> [ExamSkill: AbilityEstimator] {
        try database.reader.read { try Self.skillStates($0) }
    }

    static func skillStates(_ db: Database) throws -> [ExamSkill: AbilityEstimator] {
        var states = Dictionary(uniqueKeysWithValues: ExamSkill.allCases.map { ($0, AbilityEstimator()) })
        for record in try SkillStateRecord.fetchAll(db) {
            if let skill = ExamSkill(rawValue: record.skill), let estimator = record.estimator { states[skill] = estimator }
        }
        return states
    }

    /// Starting posteriors for a new attempt: the stored states, or the B1+ prior N(-0.3, 1) for
    /// skills never estimated. A second placement probe therefore builds on the first.
    public func priors(for kind: ExamKind) throws -> [ExamSkill: AbilityEstimator] {
        try skillStates()
    }

    /// Item ids answered in attempts started since `date` (so a new attempt avoids repeats).
    public func recentItemIds(since date: Date) throws -> Set<String> {
        try database.reader.read { db in
            Set(try String.fetchAll(db, sql: """
                SELECT r.itemId FROM exam_response r JOIN exam_attempt a ON a.id = r.attemptId WHERE a.startedAt >= ?
                """, arguments: [Self.ms(date)]))
        }
    }

    // MARK: Attempts

    /// - Parameter mockGroupId: shared by the attempts of one sectioned weekly/monthly mock.
    public func begin(_ session: ExamSession, mockGroupId: String? = nil) throws {
        try database.writer.write { db in
            try ExamAttemptRecord(id: session.id, kind: session.blueprint.kind.rawValue, blueprintId: session.blueprint.id,
                                  seed: Int64(bitPattern: session.seed), startedAt: Self.ms(session.startedAt), endedAt: nil,
                                  status: "running", integrity: nil, integrityConfirmed: false,
                                  integrityJSON: nil, pausedMs: 0, routes: nil, mockGroupId: mockGroupId,
                                  priors: Self.priorsBlob(session.priors), excluded: Self.json(session.excluding.sorted())).insert(db)
        }
    }

    /// Writes the latest answer as soon as it is given (PLAN F5 step 6), so a crash or a Tivra
    /// quit loses nothing. Unscored until submit; idempotent per task.
    public func recordResponse(_ session: ExamSession, taskId: String) throws {
        guard let task = session.tasks.first(where: { $0.id == taskId }) else { return }
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM exam_response WHERE attemptId = ? AND itemId = ?", arguments: [session.id, taskId])
            var row = try Self.responseRow(session, task)
            row.scoreSource = "pending"
            try row.insert(db)
            try db.execute(sql: "UPDATE exam_attempt SET pausedMs = ? WHERE id = ?", arguments: [session.pausedMs, session.id])
        }
    }

    /// Stores a voided attempt: the responses are kept for review, nothing is scored.
    /// An attempt that is already done or void is left alone (a stale runner can't rewrite it).
    public func void(_ session: ExamSession) throws {
        try database.writer.write { db in
            guard try !Self.isClosed(db, session.id) else { return }
            try Self.closeAttempt(db, session, status: "void")
            try db.execute(sql: "DELETE FROM exam_response WHERE attemptId = ?", arguments: [session.id])
            for task in session.tasks {
                var row = try Self.responseRow(session, task)
                row.scoreSource = "void"
                try row.insert(db)
            }
        }
    }

    /// Stores a submitted attempt: responses, skill states, band rows, and one writing entry +
    /// Claude job per pending grade. Returns the queued job ids.
    @discardableResult
    public func save(_ session: ExamSession, outcome: ExamOutcome) throws -> [Int64] {
        try database.writer.write { db in
            // Saving twice (a stale runner of the same attempt) must not re-apply skill states,
            // add band rows or queue duplicate grades.
            guard try !Self.isClosed(db, session.id) else { return [] }
            let now = Self.ms(session.endedAt ?? Date())
            let day = DayBoundary.day(for: Self.date(now))
            try Self.closeAttempt(db, session, status: "done")
            try db.execute(sql: "DELETE FROM exam_response WHERE attemptId = ?", arguments: [session.id])
            let scores = Dictionary(outcome.taskScores.map { ($0.taskId, $0) }, uniquingKeysWith: { a, _ in a })
            for task in session.tasks {
                var row = try Self.responseRow(session, task)
                if let s = scores[task.id] {
                    row.correct = s.correct
                    row.scoreRaw = s.scoreRaw
                    row.scoreMax = s.scoreMax
                    row.scoreSource = s.source
                }
                try row.insert(db)
            }
            // Placement grants every starting state; other exams update the skills they touched.
            let skills = outcome.kind == .placement ? ExamSkill.allCases : outcome.skills.map(\.skill)
            for skill in skills {
                guard let estimate = outcome.estimates[skill] else { continue }
                try SkillStateRecord(skill: skill, estimator: estimate, updatedAt: now).save(db)
            }
            for skill in outcome.skills where !skill.pending {
                try Self.insertBand(db, ts: now, day: day, attemptId: session.id, kind: outcome.kind.rawValue,
                                    skill: skill.skill.rawValue, estimate: skill.estimate, verified: false)
            }
            var jobs: [Int64] = []
            for p in outcome.pending {
                var entry = WritingEntryRecord(
                    id: nil, ts: now, surface: "exam", attemptId: session.id, skill: p.skill.rawValue, promptId: p.taskId,
                    prompt: p.prompt, text: p.text, wordCount: TextMetrics(text: p.text).wordCount,
                    metrics: Self.json(TextMetrics(text: p.text)), localGate: nil, gradeStatus: "pending", gradeJSON: nil,
                    rubricVersion: GradingRubric.version, localOnly: false)
                try entry.insert(db)
                let payload = GradeJobPayload(entryId: entry.id!, skill: p.skill, kind: p.kind, runs: outcome.kind.gradingRuns,
                                              weight: outcome.kind.evidenceWeight, typed: p.typed)
                var job = ClaudeJobRecord(id: nil, kind: "grade", attemptId: session.id, payload: Self.json(payload) ?? "{}",
                                          status: "queued", attempts: 0, nextAttemptAt: now, createdAt: now,
                                          finishedAt: nil, result: nil, error: nil)
                try job.insert(db)
                jobs.append(job.id!)
            }
            try Self.finalizeIfComplete(db, attemptId: session.id, now: now)
            return jobs
        }
    }

    static func isClosed(_ db: Database, _ attemptId: String) throws -> Bool {
        let status = try String.fetchOne(db, sql: "SELECT status FROM exam_attempt WHERE id = ?", arguments: [attemptId])
        return status == "done" || status == "void"
    }

    public func attempt(_ id: String) throws -> ExamAttemptRecord? {
        try database.reader.read { try ExamAttemptRecord.fetchOne($0, key: id) }
    }

    /// Bands recorded for one attempt (per skill, "overall", and "public" after a placement).
    public func bands(attemptId: String) throws -> [BandHistoryRecord] {
        try database.reader.read {
            try BandHistoryRecord.filter(Column("attemptId") == attemptId).order(Column("id")).fetchAll($0)
        }
    }

    // MARK: Integrity

    public func logIntegrity(attemptId: String, kind: IntegrityEventKind, detail: String? = nil,
                             durationMs: Int64? = nil, at date: Date) throws {
        try database.writer.write { db in
            var event = IntegrityEvent(attemptId: attemptId, ts: Self.ms(date), kind: kind, detail: detail, durationMs: durationMs)
            try event.insert(db)
        }
    }

    /// Sets the verdict (from `IntegrityVerifier`, M11) and whether the learner confirmed a WARNING;
    /// the attempt's band rows become verified when the verdict counts. Until then it is NULL (pending).
    public func setIntegrity(attemptId: String, _ verdict: IntegrityLevel, confirmed: Bool = false, json: String? = nil) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE exam_attempt SET integrity = ?, integrityConfirmed = ?, integrityJSON = ? WHERE id = ?",
                           arguments: [verdict.rawValue, confirmed, json, attemptId])
            try db.execute(sql: "UPDATE band_history SET verified = ? WHERE attemptId = ? AND skill != ?",
                           arguments: [verdict.counts(confirmed: confirmed), attemptId, BandHistoryRecord.publicBand])
        }
    }

    // MARK: Public band and promotion

    /// The public band: set by placement, raised only by promotion. Nil before placement.
    public func publicBand() throws -> Double? {
        try database.reader.read { try Self.publicBand($0) }
    }

    static func publicBand(_ db: Database) throws -> Double? {
        try Double.fetchOne(db, sql: "SELECT max(band) FROM band_history WHERE skill = ?", arguments: [BandHistoryRecord.publicBand])
    }

    /// The learner's current overall band: the one recorded by their latest placement or exam, else the
    /// public band, else nil (no exam yet). The Library recommends at this level.
    public func currentBand() throws -> Double? {
        try database.reader.read { db in
            try Double.fetchOne(db, sql: "SELECT band FROM band_history WHERE skill = ? ORDER BY ts DESC, id DESC LIMIT 1",
                                arguments: [BandHistoryRecord.overall]) ?? Self.publicBand(db)
        }
    }

    /// Monthly Mocks may be taken section by section (PLAN F5): attempts sharing a `mockGroupId`
    /// form one mock, which counts only if it covers all four sections within `mockWindow` of its
    /// first start and every one of its attempts is verified. Its overall theta is the one recorded
    /// after its last section (the skill states then hold every section's evidence).
    public static let mockWindow: TimeInterval = 72 * 3600

    public func promotionEvidence() throws -> (monthlies: [MonthlyEvidence], weeklies: [WeeklyEvidence]) {
        try database.reader.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.id, a.kind, a.mockGroupId, a.startedAt, a.endedAt, a.integrity, a.integrityConfirmed, b.thetaMean, b.sd
                FROM exam_attempt a JOIN band_history b ON b.attemptId = a.id AND b.skill = ?
                WHERE a.status = 'done' AND a.kind IN ('monthly', 'weekly') ORDER BY a.endedAt, a.id
                """, arguments: [BandHistoryRecord.overall])
            var weeklies: [WeeklyEvidence] = []
            var groups: [String: [Row]] = [:]
            var order: [String] = []
            for row in rows {
                let id: String = row["id"]
                if (row["kind"] as String) == ExamKind.weekly.rawValue {
                    weeklies.append(WeeklyEvidence(attemptId: id, endedAt: Self.date(row["endedAt"] ?? 0), overallMean: row["thetaMean"]))
                    continue
                }
                let group: String = row["mockGroupId"] ?? id
                if groups[group] == nil { order.append(group) }
                groups[group, default: []].append(row)
            }
            var monthlies: [MonthlyEvidence] = []
            for key in order {
                guard let attempts = groups[key], let last = attempts.last else { continue }
                var bands: [ExamSkill: Double] = [:]
                var verified = true
                for row in attempts {
                    let id: String = row["id"]
                    for b in try BandHistoryRecord.filter(Column("attemptId") == id).order(Column("id")).fetchAll(db) {
                        if let skill = ExamSkill(rawValue: b.skill) { bands[skill] = b.band } // latest row wins
                    }
                    verified = verified && IntegrityLevel.counts(stored: row["integrity"], confirmed: row["integrityConfirmed"])
                }
                let firstStart: Int64 = attempts.map { $0["startedAt"] as Int64 }.min() ?? 0
                let lastEnd: Int64 = last["endedAt"] ?? 0
                let inWindow = Double(lastEnd - firstStart) / 1000 <= Self.mockWindow
                let complete = ExamSkill.sections.allSatisfy { bands[$0] != nil }
                monthlies.append(MonthlyEvidence(attemptId: last["id"], endedAt: Self.date(lastEnd), overallMean: last["thetaMean"],
                                                 overallSD: last["sd"], sectionBands: bands,
                                                 verified: verified && inWindow && complete))
            }
            return (monthlies, weeklies)
        }
    }

    /// Checks the promotion rules and, on success, records the new public band. Never lowers it.
    @discardableResult
    public func evaluatePromotion(anchorDriftOK: Bool, at date: Date) throws -> PromotionDecision {
        guard let current = try publicBand() else { return .hold(reasons: ["no placement yet"]) }
        var evidence = try promotionEvidence()
        // Each step needs fresh monthlies: the ones that earned the last promotion cannot earn another.
        let lastPromotion = try database.reader.read {
            try Int64.fetchOne($0, sql: "SELECT max(ts) FROM band_history WHERE kind = 'promotion'")
        }
        if let lastPromotion {
            evidence.monthlies.removeAll { $0.endedAt <= Self.date(lastPromotion) }
        }
        let decision = PromotionRules.evaluate(current: current, monthlies: evidence.monthlies,
                                               weeklies: evidence.weeklies, anchorDriftOK: anchorDriftOK)
        if case let .promote(_, to) = decision {
            try database.writer.write { db in
                let latest = evidence.monthlies.max { $0.endedAt < $1.endedAt }
                var row = BandHistoryRecord(id: nil, ts: Self.ms(date), day: DayBoundary.day(for: date), attemptId: latest?.attemptId,
                                            kind: "promotion", skill: BandHistoryRecord.publicBand, band: max(current, to),
                                            low: max(current, to), high: max(current, to), thetaMean: latest?.overallMean ?? 0,
                                            sd: latest?.overallSD ?? 0, verified: true)
                try row.insert(db)
            }
        }
        return decision
    }

    // MARK: Helpers shared with ClaudeJobQueue

    static func closeAttempt(_ db: Database, _ session: ExamSession, status: String) throws {
        let routes = json(session.routes.mapValues(\.rawValue))
        try db.execute(sql: "UPDATE exam_attempt SET endedAt = ?, status = ?, pausedMs = ?, routes = ? WHERE id = ?",
                       arguments: [ms(session.endedAt ?? Date()), status, session.pausedMs, routes, session.id])
    }

    static func responseRow(_ session: ExamSession, _ task: ExamTask) throws -> ExamResponseRecord {
        let response = session.response(for: task.id)
        return ExamResponseRecord(id: nil, attemptId: session.id, itemId: task.id, sectionId: task.sectionId,
                                  skill: task.skill.rawValue, answer: response?.answer.flatMap { json($0) }, correct: nil,
                                  latencyMs: response.map { Int64($0.latencyMs) }, scoreRaw: nil, scoreMax: nil,
                                  scoreSource: "objective")
    }

    static func insertBand(_ db: Database, ts: Int64, day: Int, attemptId: String?, kind: String, skill: String,
                           estimate: AbilityEstimator, verified: Bool) throws {
        let range = estimate.bandRange
        var row = BandHistoryRecord(id: nil, ts: ts, day: day, attemptId: attemptId, kind: kind, skill: skill,
                                    band: estimate.band, low: range.lowerBound, high: range.upperBound,
                                    thetaMean: estimate.mean, sd: estimate.sd, verified: verified)
        try row.insert(db)
    }

    /// Once no grading job is left for the attempt, records its overall band (from the current
    /// skill states); a placement also sets the first public band, but only once every grade
    /// arrived: a job that failed (Claude offline, logged out) leaves writing/speaking at the prior,
    /// and the public band is "raised only by promotion", so it must not be fixed on a prior.
    /// A failed job retried later (`requeueFailedJobs`) finalizes again: the overall row is
    /// refreshed and the public band set then.
    static func finalizeIfComplete(_ db: Database, attemptId: String, now: Int64) throws {
        guard let attempt = try ExamAttemptRecord.fetchOne(db, key: attemptId), attempt.status == "done" else { return }
        let open = try Int.fetchOne(db, sql: "SELECT count(*) FROM claude_job WHERE attemptId = ? AND status IN ('queued', 'running')",
                                    arguments: [attemptId]) ?? 0
        guard open == 0 else { return }
        let failed = try Int.fetchOne(db, sql: "SELECT count(*) FROM writing_entry WHERE attemptId = ? AND gradeStatus = 'failed'",
                                      arguments: [attemptId]) ?? 0
        let existing = try BandHistoryRecord.fetchOne(db, sql: "SELECT * FROM band_history WHERE attemptId = ? AND skill = ? ORDER BY id DESC",
                                                      arguments: [attemptId, BandHistoryRecord.overall])
        let isPlacement = attempt.kind == ExamKind.placement.rawValue
        let publicMissing = try isPlacement && publicBand(db) == nil
        // Already final, and nothing left to set: later calls are no-ops.
        if existing != nil, !(publicMissing && failed == 0) { return }
        let overall = OverallBand(estimates: try skillStates(db))
        let verified = IntegrityLevel.counts(stored: attempt.integrity, confirmed: attempt.integrityConfirmed)
        let day = DayBoundary.day(for: date(now))
        var row = BandHistoryRecord(id: existing?.id, ts: existing?.ts ?? now, day: existing?.day ?? day, attemptId: attemptId,
                                    kind: attempt.kind, skill: BandHistoryRecord.overall,
                                    band: overall.band, low: overall.low, high: overall.high, thetaMean: overall.thetaMean,
                                    sd: overall.sd, verified: verified)
        if existing == nil { try row.insert(db) } else { try row.update(db) }
        if publicMissing, failed == 0 {
            row.id = nil
            row.ts = now
            row.day = day
            row.skill = BandHistoryRecord.publicBand
            try row.insert(db)
        }
    }

    /// The five posteriors of `priors` back to back, in `ExamSkill.allCases` order.
    static func priorsBlob(_ priors: [ExamSkill: AbilityEstimator]) -> Data {
        ExamSkill.allCases.reduce(into: Data()) { $0.append((priors[$1] ?? AbilityEstimator()).blob) }
    }

    static func json<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) }
    }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String?) -> T? {
        json.flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
    }
}
