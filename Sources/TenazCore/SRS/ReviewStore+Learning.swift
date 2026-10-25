import Foundation
import GRDB

public extension ReviewStore {
    /// The scheduler counts the gamification engine needs (`GamificationEngine.updateLearning`).
    /// "Mastered" is counted per note on its primary card (L recall if the note has one, else C cloze):
    /// stability at or above `stages.mastered.minStabilityDays` and the last
    /// `stages.mastered.lastCorrectRecalls` answers on that card all right (PLAN F8).
    func learningSnapshot(now: Date, stages: StageConfig) throws -> LearningSnapshot {
        let nowMs = now.unixMilliseconds
        return try database.reader.read { db in
            let introduced = try Int.fetchOne(db, sql: """
            SELECT COUNT(DISTINCT card.noteId) FROM review_log JOIN card ON card.id = review_log.cardId
            """) ?? 0
            let due = try Row.fetchOne(db, sql: """
            SELECT COUNT(*) AS n, MIN(card.due) AS oldest FROM card JOIN note ON note.id = card.noteId
            WHERE card.state != 'new' AND card.due <= ? AND note.suspended = 0
            """, arguments: [nowMs])
            let dueCount: Int = due?["n"] ?? 0
            let oldest: Int64? = due?["oldest"]
            let overdueHours = oldest.map { max(0, Double(nowMs - $0) / 3_600_000) } ?? 0

            // Primary card per note: L if present, else C.
            let candidates = try Row.fetchAll(db, sql: """
            SELECT card.id, card.noteId, card.type, card.stability FROM card
            WHERE card.type IN ('L', 'C') AND card.stability >= ?
            """, arguments: [stages.mastered.minStabilityDays])
            let hasRecall = try Set(String.fetchAll(db, sql: "SELECT noteId FROM card WHERE type = 'L'"))
            var mastered = 0
            for row in candidates {
                let noteId: String = row["noteId"]
                let type: String = row["type"]
                guard type == "L" || !hasRecall.contains(noteId) else { continue }
                let recent = try Int.fetchAll(db, sql: "SELECT rating FROM review_log WHERE cardId = ? ORDER BY ts DESC LIMIT ?",
                                              arguments: [row["id"] as String, stages.mastered.lastCorrectRecalls])
                let correct = recent.count(where: { $0 != Rating.again.rawValue })
                if stages.isMastered(stabilityDays: row["stability"], lastRecallsCorrect: correct) { mastered += 1 }
            }
            return LearningSnapshot(notesIntroduced: introduced, masteredNotes: mastered, dueCount: dueCount,
                                    oldestOverdueHours: overdueHours)
        }
    }
}
