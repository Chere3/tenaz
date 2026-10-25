import Foundation
import GRDB

/// Where an unfinished attempt stopped (`exam_progress`), so it can be rebuilt by replay:
/// the section the learner paused before, whether they paused on purpose, and per-task notes such as
/// "listening item read instead of heard".
public struct ExamProgressRecord: Codable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "exam_progress"
    public var attemptId: String
    /// Blueprint index of the section the attempt is in (or about to start); nil once every section is done.
    public var sectionIndex: Int?
    /// True when the learner chose "Pause between sections" (resumable any time); false while running.
    public var pausedBetweenSections: Bool
    /// Unix ms of the last answer or pause, used to tell a crash from a long break.
    public var updatedAt: Int64
    /// JSON `[taskId: note]`, e.g. "readInstead" or "typedInstead".
    public var notes: String?

    public init(attemptId: String, sectionIndex: Int?, pausedBetweenSections: Bool, updatedAt: Int64, notes: String? = nil) {
        self.attemptId = attemptId
        self.sectionIndex = sectionIndex
        self.pausedBetweenSections = pausedBetweenSections
        self.updatedAt = updatedAt
        self.notes = notes
    }

    public var noteMap: [String: String] { ExamStore.decode([String: String].self, notes) ?? [:] }
}
