import Foundation
import GRDB

/// Unfinished attempts: progress rows, history, and rebuilding a session by deterministic replay
/// (same seed, priors and excluded ids; the stored answers in order). PLAN F5 step 6.
extension ExamStore {
    /// A crashed attempt (not paused on purpose) can be resumed for this long; after that a mock
    /// closes as `abandoned`. Placement stays resumable: it moves no public band.
    public static let crashResumeWindow: TimeInterval = 15 * 60

    // MARK: Progress

    public func saveProgress(_ session: ExamSession, pausedBetweenSections: Bool, note: (taskId: String, text: String)? = nil,
                             at date: Date) throws {
        try database.writer.write { db in
            var notes = try ExamProgressRecord.fetchOne(db, key: session.id)?.noteMap ?? [:]
            if let note { notes[note.taskId] = note.text }
            try ExamProgressRecord(attemptId: session.id, sectionIndex: session.sectionIndex,
                                   pausedBetweenSections: pausedBetweenSections, updatedAt: Self.ms(date),
                                   notes: notes.isEmpty ? nil : Self.json(notes)).save(db)
            try db.execute(sql: "UPDATE exam_attempt SET pausedMs = ? WHERE id = ?", arguments: [session.pausedMs, session.id])
        }
    }

    public func progress(_ attemptId: String) throws -> ExamProgressRecord? {
        try database.reader.read { try ExamProgressRecord.fetchOne($0, key: attemptId) }
    }

    /// Attempts still `running` (paused between sections, or cut off by a crash or quit), newest first.
    public func unfinishedAttempts(kind: ExamKind? = nil) throws -> [ExamAttemptRecord] {
        try database.reader.read { db in
            var request = ExamAttemptRecord.filter(Column("status") == "running")
            if let kind { request = request.filter(Column("kind") == kind.rawValue) }
            return try request.order(Column("startedAt").desc).fetchAll(db)
        }
    }

    /// Whether an unfinished attempt can still be resumed at `now`.
    public func isResumable(_ attempt: ExamAttemptRecord, now: Date) throws -> Bool {
        guard attempt.status == "running" else { return false }
        if attempt.kind == ExamKind.placement.rawValue { return true }
        guard let p = try progress(attempt.id) else { return false }
        if p.pausedBetweenSections { return true }
        return now.timeIntervalSince(Self.date(p.updatedAt)) <= Self.crashResumeWindow
    }

    /// Closes an attempt that can no longer be resumed: practice statistics only, never scored.
    public func abandon(_ attemptId: String, at date: Date) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE exam_attempt SET status = 'abandoned', endedAt = ? WHERE id = ? AND status = 'running'",
                           arguments: [Self.ms(date), attemptId])
        }
    }

    public func responses(attemptId: String) throws -> [ExamResponseRecord] {
        try database.reader.read {
            try ExamResponseRecord.filter(Column("attemptId") == attemptId).order(Column("id")).fetchAll($0)
        }
    }

    // MARK: History

    /// Every attempt, newest first, with its overall band once recorded.
    public func history(limit: Int = 50) throws -> [ExamAttemptSummary] {
        try database.reader.read { db in
            try ExamAttemptRecord.order(Column("startedAt").desc).limit(limit).fetchAll(db).map { a in
                let bands = try BandHistoryRecord.filter(Column("attemptId") == a.id).order(Column("id")).fetchAll(db)
                var skills: [ExamSkill: Double] = [:]
                for b in bands { if let s = ExamSkill(rawValue: b.skill) { skills[s] = b.band } }
                let overall = bands.last { $0.skill == BandHistoryRecord.overall }
                let answered = try Int.fetchOne(db, sql: "SELECT count(*) FROM exam_response WHERE attemptId = ? AND answer IS NOT NULL",
                                                arguments: [a.id]) ?? 0
                return ExamAttemptSummary(
                    id: a.id, kind: ExamKind(rawValue: a.kind) ?? .daily, startedAt: Self.date(a.startedAt),
                    endedAt: a.endedAt.map(Self.date), status: a.status, overall: overall?.band, low: overall?.low, high: overall?.high,
                    integrity: a.integrity.flatMap(IntegrityLevel.init(rawValue:)), integrityConfirmed: a.integrityConfirmed,
                    skillBands: skills, answered: answered)
            }
        }
    }

    // MARK: Replay

    /// Rebuilds the session of an unfinished attempt and leaves it paused at the point where it
    /// stopped. Call `clock.goLive()` and `session.resume()` when the learner continues: the gap goes into
    /// `pausedMs`. Throws if the stored answers no longer match the rebuilt tasks (content changed).
    public func restore(_ attemptId: String, catalog: BlueprintCatalog, library: ContentLibrary)
        throws -> (session: ExamSession, clock: ReplayClock) {
        guard let attempt = try attempt(attemptId) else { throw ExamResumeError.notFound }
        guard let blueprint = catalog.blueprints.first(where: { $0.id == attempt.blueprintId }) else {
            throw ExamResumeError.blueprintMissing(attempt.blueprintId)
        }
        let clock = ReplayClock(start: Self.date(attempt.startedAt))
        var session = ExamSession(id: attempt.id, blueprint: blueprint, library: library,
                                  priors: Self.priors(fromBlob: attempt.priors),
                                  excluding: Set(Self.decode([String].self, attempt.excluded) ?? []),
                                  seed: UInt64(bitPattern: attempt.seed), clock: clock)
        for row in try responses(attemptId: attemptId) {
            while let task = session.currentTask, task.sectionId != row.sectionId { session.endSection() }
            guard let task = session.currentTask, task.id == row.itemId else {
                throw ExamResumeError.mismatch(row.itemId)
            }
            clock.advance(by: Double(row.latencyMs ?? 0) / 1000)
            session.answer(Self.decode(ExamAnswer.self, row.answer))
        }
        if let target = try progress(attemptId)?.sectionIndex {
            while let index = session.sectionIndex, index < target { session.endSection() }
        }
        session.pause(.user)
        return (session, clock)
    }

    /// The `priors` blob back into five posteriors (fresh B1+ priors for anything missing).
    static func priors(fromBlob blob: Data?) -> [ExamSkill: AbilityEstimator] {
        let size = AbilityEstimator.grid.count * 8
        var result: [ExamSkill: AbilityEstimator] = [:]
        for (i, skill) in ExamSkill.allCases.enumerated() {
            if let blob, blob.count >= (i + 1) * size,
               let est = AbilityEstimator(blob: blob.subdata(in: (blob.startIndex + i * size)..<(blob.startIndex + (i + 1) * size))) {
                result[skill] = est
            } else {
                result[skill] = AbilityEstimator()
            }
        }
        return result
    }
}

public enum ExamResumeError: Error, Equatable, CustomStringConvertible {
    case notFound
    case blueprintMissing(String)
    case mismatch(String)

    public var description: String {
        switch self {
        case .notFound: "That exam is gone."
        case let .blueprintMissing(id): "The exam plan \(id) is missing."
        case let .mismatch(id): "The questions changed since you started (\(id))."
        }
    }
}
