import Foundation
import GRDB

/// Database side of reviewing: today's counts, today's set, and saving each answer.
public struct ReviewStore: Sendable {
    public let database: TenazDatabase

    public init(database: TenazDatabase) { self.database = database }

    /// Answers and note introductions since today's 04:00 boundary.
    public func dailyCounts(now: Date) throws -> DailyCounts {
        let start = DayBoundary.start(ofDayContaining: now).unixMilliseconds
        return try database.reader.read { db in
            let answered = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM review_log WHERE ts >= ?", arguments: [start]) ?? 0
            let introduced = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM (
                    SELECT card.noteId, MIN(review_log.ts) AS first FROM review_log
                    JOIN card ON card.id = review_log.cardId GROUP BY card.noteId
                ) WHERE first >= ?
                """, arguments: [start]) ?? 0
            return DailyCounts(newIntroduced: introduced, answered: answered)
        }
    }

    /// Today's set (see `ReviewQueue.build`) with each card's note; "Learn this next" picks go first.
    public func todaySet(now: Date, limits: QueueLimits = .standard) throws -> [(card: CardRecord, note: NoteRecord)] {
        let counts = try dailyCounts(now: now)
        let (cards, notes, picked) = try database.reader.read { db in
            (try CardRecord.fetchAll(db), try NoteRecord.fetchAll(db), Set(try String.fetchAll(db, sql: "SELECT noteId FROM deck_pick")))
        }
        let byId = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let set = ReviewQueue.build(cards: cards, notes: byId, today: counts, day: DayBoundary.day(for: now), now: now, limits: limits,
                                    picked: picked)
        return set.compactMap { c in byId[c.noteId].map { (c, $0) } }
    }

    /// A session over today's set; cards whose bundled entry is gone are skipped.
    public func startSession(
        book: PromptBook, surface: ReviewSurface, now: Date, limits: QueueLimits = .standard,
        onEvent: (@Sendable (ReviewEvent) -> Void)? = nil
    ) throws -> ReviewSession {
        let items = try todaySet(now: now, limits: limits).compactMap { pair in
            book.prompt(for: pair.card, note: pair.note).map { SessionItem(card: pair.card, note: pair.note, prompt: $0) }
        }
        return ReviewSession(items: items, surface: surface, onEvent: onEvent)
    }

    /// Saves the card, appends the log row and buries the note's other cards for the rest of the day.
    public func record(_ outcome: ReviewOutcome) throws {
        try database.writer.write { db in
            try outcome.after.update(db)
            var log = outcome.log
            try log.insert(db)
            try db.execute(
                sql: "UPDATE card SET buriedUntilDay = ? WHERE noteId = ? AND id != ?",
                arguments: [outcome.buryDay, outcome.after.noteId, outcome.after.id]
            )
        }
    }
}
