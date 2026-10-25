import Foundation
import GRDB

/// One answered card (`review_log` table): everything a future FSRS optimizer needs.
public struct ReviewLogRecord: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "review_log"

    public var id: Int64?
    public var cardId: String
    public var ts: Int64
    public var rating: Int
    public var stateBefore: CardStatus
    public var stateAfter: CardStatus
    public var sBefore: Double?
    public var sAfter: Double?
    public var dBefore: Double?
    public var dAfter: Double?
    public var elapsedDays: Double
    public var scheduledDays: Double
    public var durationMs: Int
    public var inputMode: InputMode
    public var surface: ReviewSurface
    public var answerText: String?
    public var appFocusOk: Bool?

    /// Builds the row for a review that turned `before` into `after`.
    public init(
        before: CardRecord, after: CardRecord, rating: Rating, at now: Date, durationMs: Int,
        inputMode: InputMode, surface: ReviewSurface, answerText: String?, appFocusOk: Bool? = nil
    ) {
        let nowMs = now.unixMilliseconds
        cardId = before.id
        ts = nowMs
        self.rating = rating.rawValue
        stateBefore = before.state
        stateAfter = after.state
        sBefore = before.stability
        sAfter = after.stability
        dBefore = before.difficulty
        dAfter = after.difficulty
        elapsedDays = before.lastReview.map { max(0, Double(nowMs - $0) / 86_400_000) } ?? 0
        scheduledDays = before.lastReview.map { max(0, Double(before.due - $0) / 86_400_000) } ?? 0
        self.durationMs = durationMs
        self.inputMode = inputMode
        self.surface = surface
        self.answerText = answerText
        self.appFocusOk = appFocusOk
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
