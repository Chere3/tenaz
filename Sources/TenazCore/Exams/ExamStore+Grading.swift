import Foundation
import GRDB

/// The `claude_job` side of the store, used by `ClaudeJobQueue`.
extension ExamStore {
    /// A claimed job with what it needs.
    public struct GradeJob: Sendable {
        public var job: ClaudeJobRecord
        public var payload: GradeJobPayload
        public var entry: WritingEntryRecord
        /// Runs already finished (a retried monthly job resumes after them).
        public var finishedRuns: [GradeResult]
    }

    /// Saves a free piece of writing (the Write sheet) as a `writing_entry` and queues its Claude
    /// grade, like a gate paragraph (light evidence for the writing skill). Returns the entry id.
    @discardableResult
    public func saveWriting(surface: String, promptId: String?, prompt: String, text: String, at date: Date) throws -> Int64 {
        try database.writer.write { db in
            let ts = Self.ms(date)
            let metrics = TextMetrics(text: text)
            var entry = WritingEntryRecord(id: nil, ts: ts, surface: surface, attemptId: nil, skill: ExamSkill.writing.rawValue,
                                           promptId: promptId, prompt: prompt, text: text, wordCount: metrics.wordCount,
                                           metrics: Self.json(metrics), localGate: nil, gradeStatus: "pending", gradeJSON: nil,
                                           rubricVersion: GradingRubric.version, localOnly: false)
            try entry.insert(db)
            guard let id = entry.id else { return -1 }
            let payload = GradeJobPayload(entryId: id, skill: .writing, kind: .writing, runs: 1, weight: 0.25, typed: true)
            var job = ClaudeJobRecord(id: nil, kind: "grade", attemptId: nil, payload: Self.json(payload) ?? "{}", status: "queued",
                                      attempts: 0, nextAttemptAt: ts, createdAt: ts, finishedAt: nil, result: nil, error: nil)
            try job.insert(db)
            return id
        }
    }

    /// Jobs left `running` by a crash or quit go back to the queue.
    /// Gives failed jobs (Claude offline or logged out for a morning) a fresh set of attempts, and
    /// their entries back to pending, so their grades still arrive. Called on each normal launch.
    @discardableResult
    public func requeueFailedJobs(at date: Date) throws -> Int {
        try database.writer.write { db in
            try db.execute(sql: """
                UPDATE writing_entry SET gradeStatus = 'pending' WHERE gradeStatus = 'failed'
                  AND id IN (SELECT json_extract(payload, '$.entryId') FROM claude_job WHERE status = 'failed')
                """)
            try db.execute(sql: "UPDATE claude_job SET status = 'queued', attempts = 0, nextAttemptAt = ?, finishedAt = NULL WHERE status = 'failed'",
                           arguments: [Self.ms(date)])
            return db.changesCount
        }
    }

    public func resetRunningJobs() throws {
        try database.writer.write { try $0.execute(sql: "UPDATE claude_job SET status = 'queued' WHERE status = 'running'") }
    }

    public func job(_ id: Int64) throws -> ClaudeJobRecord? {
        try database.reader.read { try ClaudeJobRecord.fetchOne($0, key: id) }
    }

    public func writingEntry(_ id: Int64) throws -> WritingEntryRecord? {
        try database.reader.read { try WritingEntryRecord.fetchOne($0, key: id) }
    }

    /// Marks the oldest due queued job as running and returns it. Jobs with a broken payload fail.
    public func claimNextJob(now: Date) throws -> GradeJob? {
        try database.writer.write { db in
            while let job = try ClaudeJobRecord
                .filter(Column("status") == "queued" && Column("nextAttemptAt") <= Self.ms(now))
                .order(Column("nextAttemptAt"), Column("id")).fetchOne(db) {
                guard let payload = Self.decode(GradeJobPayload.self, job.payload),
                      let entry = try WritingEntryRecord.fetchOne(db, key: payload.entryId) else {
                    try db.execute(sql: "UPDATE claude_job SET status = 'failed', error = 'bad payload', finishedAt = ? WHERE id = ?",
                                   arguments: [Self.ms(now), job.id])
                    continue
                }
                try db.execute(sql: "UPDATE claude_job SET status = 'running' WHERE id = ?", arguments: [job.id])
                var claimed = job
                claimed.status = "running"
                let runs = Self.decode(WritingGrade.self, entry.gradeJSON)?.runs ?? []
                return GradeJob(job: claimed, payload: payload, entry: entry, finishedRuns: runs)
            }
            return nil
        }
    }

    public func gradeRequest(for job: GradeJob) throws -> GradeRequest {
        let band = try skillStates()[job.payload.skill]?.band ?? AbilityEstimator().band
        return GradeRequest(kind: job.payload.kind, taskPrompt: job.entry.prompt, response: job.entry.text,
                            learnerBand: band, typed: job.payload.typed)
    }

    /// Stores one finished run: a `grade_run` row per criterion, and the run in the entry's gradeJSON.
    public func saveRun(_ result: GradeResult, entryId: Int64, runIndex: Int, model: String, at date: Date) throws {
        try database.writer.write { db in
            let now = Self.ms(date)
            for c in result.criteria {
                var row = GradeRunRecord(id: nil, ts: now, targetKind: "writing_entry", targetId: entryId, criterion: c.name,
                                         score: Double(c.score), evidence: Self.json(c.evidenceQuotes), cefr: c.cefr, model: model,
                                         runIndex: runIndex, rubricVersion: GradingRubric.version,
                                         calibrationVersion: GradingRubric.calibrationVersion)
                try row.insert(db)
            }
            guard var entry = try WritingEntryRecord.fetchOne(db, key: entryId) else { return }
            var grade = Self.decode(WritingGrade.self, entry.gradeJSON) ?? WritingGrade(runs: [])
            grade.runs.append(result)
            entry.gradeJSON = Self.json(grade)
            try entry.update(db)
        }
    }

    /// All runs are in: median per criterion, entry graded, errors into the ledger (first run only),
    /// the skill posterior updated, a band row written, and the attempt finalized if nothing is left.
    @discardableResult
    public func completeGrade(_ job: GradeJob, at date: Date) throws -> WritingGrade {
        try database.writer.write { db in
            let now = Self.ms(date)
            guard var entry = try WritingEntryRecord.fetchOne(db, key: job.payload.entryId) else {
                throw ClaudeCLIError.failed("writing entry \(job.payload.entryId) is gone")
            }
            var grade = Self.decode(WritingGrade.self, entry.gradeJSON) ?? WritingGrade(runs: [])
            grade.medians = GradeAggregator.medians(grade.runs)
            grade.score = GradeAggregator.overall(grade.runs)
            grade.lowConfidence = GradeAggregator.lowConfidence(grade.runs)
            entry.gradeJSON = Self.json(grade)
            entry.gradeStatus = "graded"
            try entry.update(db)

            for e in grade.runs.first?.errors ?? [] {
                let example = e.span.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !example.isEmpty else { continue }
                try db.execute(sql: """
                    INSERT INTO error_ledger (category, example, correction, ruleShort, count, firstSeen, lastSeen)
                    VALUES (?, ?, ?, ?, 1, ?, ?)
                    ON CONFLICT(category, example) DO UPDATE SET count = count + 1, lastSeen = excluded.lastSeen,
                        correction = excluded.correction, ruleShort = excluded.ruleShort
                    """, arguments: [e.category, example, e.correction, e.ruleShort, now, now])
            }

            var states = try Self.skillStates(db)
            var estimate = states[job.payload.skill] ?? AbilityEstimator()
            estimate.update(rubric: grade.score ?? 0, weight: job.payload.weight)
            states[job.payload.skill] = estimate
            try SkillStateRecord(skill: job.payload.skill, estimator: estimate, updatedAt: now).save(db)

            try db.execute(sql: "UPDATE claude_job SET status = 'done', finishedAt = ?, result = ?, error = NULL WHERE id = ?",
                           arguments: [now, Self.json(grade), job.job.id])
            if let attemptId = entry.attemptId, let attempt = try ExamAttemptRecord.fetchOne(db, key: attemptId) {
                let verified = IntegrityLevel.counts(stored: attempt.integrity, confirmed: attempt.integrityConfirmed)
                try Self.insertBand(db, ts: now, day: DayBoundary.day(for: date), attemptId: attemptId, kind: attempt.kind,
                                    skill: job.payload.skill.rawValue, estimate: estimate, verified: verified)
                try Self.finalizeIfComplete(db, attemptId: attemptId, now: now)
            }
            return grade
        }
    }

    /// Puts a job back in the queue. `countAttempt` is false when Claude is simply unavailable.
    public func requeue(_ jobId: Int64, countAttempt: Bool, nextAttemptAt: Date, error: String) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                UPDATE claude_job SET status = 'queued', attempts = attempts + ?, nextAttemptAt = ?, error = ? WHERE id = ?
                """, arguments: [countAttempt ? 1 : 0, Self.ms(nextAttemptAt), error, jobId])
        }
    }

    /// Gives up on a job (after max attempts): the entry is marked failed and the attempt finalizes without it.
    public func failJob(_ job: GradeJob, error: String, at date: Date) throws {
        try database.writer.write { db in
            let now = Self.ms(date)
            try db.execute(sql: "UPDATE claude_job SET status = 'failed', attempts = attempts + 1, finishedAt = ?, error = ? WHERE id = ?",
                           arguments: [now, error, job.job.id])
            try db.execute(sql: "UPDATE writing_entry SET gradeStatus = 'failed' WHERE id = ?", arguments: [job.payload.entryId])
            if let attemptId = job.entry.attemptId { try Self.finalizeIfComplete(db, attemptId: attemptId, now: now) }
        }
    }
}
