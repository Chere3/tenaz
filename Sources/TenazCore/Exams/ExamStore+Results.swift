import Foundation
import GRDB

/// Reads the results screen needs: grading entries, integrity events, and whether gamification
/// already got its credit for an attempt.
extension ExamStore {
    public func writingEntries(attemptId: String) throws -> [WritingEntryRecord] {
        try database.reader.read {
            try WritingEntryRecord.filter(Column("attemptId") == attemptId).order(Column("id")).fetchAll($0)
        }
    }

    public func integrityEvents(attemptId: String) throws -> [IntegrityEvent] {
        try database.reader.read {
            try IntegrityEvent.filter(Column("attemptId") == attemptId).order(Column("ts")).fetchAll($0)
        }
    }

    /// Jobs still waiting for Claude for this attempt.
    public func openJobCount(attemptId: String) throws -> Int {
        try database.reader.read {
            try Int.fetchOne($0, sql: "SELECT count(*) FROM claude_job WHERE attemptId = ? AND status IN ('queued', 'running')",
                            arguments: [attemptId]) ?? 0
        }
    }

    /// True once `GamificationEngine` recorded an `exam_outcome` for this attempt.
    public func isCredited(attemptId: String) throws -> Bool {
        try database.reader.read {
            try Int.fetchOne($0, sql: "SELECT count(*) FROM exam_outcome WHERE refId = ?", arguments: [attemptId]) ?? 0
        } > 0
    }

    /// Finished attempts since `since` that gamification never credited (the app quit or crashed
    /// while the results were still verifying or grading), oldest first.
    public func uncreditedAttempts(since: Date) throws -> [(id: String, kind: ExamKind)] {
        try database.reader.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, kind FROM exam_attempt a WHERE status = 'done' AND startedAt >= ?
                  AND NOT EXISTS (SELECT 1 FROM exam_outcome o WHERE o.refId = a.id) ORDER BY startedAt
                """, arguments: [Self.ms(since)]).compactMap { row in
                guard let kind = ExamKind(rawValue: row["kind"]) else { return nil }
                return (id: row["id"], kind: kind)
            }
        }
    }

    /// Objective items right and produced texts, for the streak credit.
    public func creditCounts(attemptId: String) throws -> (correct: Int, productions: Int) {
        try database.reader.read { db in
            let correct = try Int.fetchOne(db, sql: "SELECT count(*) FROM exam_response WHERE attemptId = ? AND correct = 1",
                                           arguments: [attemptId]) ?? 0
            let produced = try Int.fetchOne(db, sql: "SELECT count(*) FROM writing_entry WHERE attemptId = ?", arguments: [attemptId]) ?? 0
            return (correct, produced)
        }
    }
}
