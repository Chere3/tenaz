import Foundation
import GRDB

/// One thing Tenaz itself observed during an exam attempt (table `integrity_event`, PLAN 4.3).
/// Stores only the kind, a short label and counts; never text the learner typed or pasted.
public struct IntegrityEvent: Codable, Hashable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "integrity_event"

    public var id: Int64?
    public var attemptId: String
    /// Unix milliseconds.
    public var ts: Int64
    public var kind: IntegrityEventKind
    /// App label for `.app`, change count for `.clipboard`, WPM for `.burst`...
    public var detail: String?
    /// How long a deny-listed app stayed frontmost, for `.app`.
    public var durationMs: Int64?

    public init(id: Int64? = nil, attemptId: String, ts: Int64, kind: IntegrityEventKind, detail: String? = nil, durationMs: Int64? = nil) {
        self.id = id
        self.attemptId = attemptId
        self.ts = ts
        self.kind = kind
        self.detail = detail
        self.durationMs = durationMs
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
