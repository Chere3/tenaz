import Foundation
import GRDB

/// Database side of the Library: what the learner is reading, their reading log, Brain bites read, and the
/// words they picked to learn next. Times are passed in so tests and snapshots control them.
public struct LibraryStore: Sendable {
    public let database: TenazDatabase
    let calendar: Calendar

    public init(database: TenazDatabase, calendar: Calendar = .current) {
        self.database = database
        self.calendar = calendar
    }

    // MARK: Status

    public func items() throws -> [LibraryItemRecord] {
        try database.reader.read { try LibraryItemRecord.order(Column("updatedAt")).fetchAll($0) }
    }

    public func setStatus(_ itemId: String, _ status: LibraryStatus, reason: String? = nil, now: Date) throws {
        let ms = now.unixMilliseconds
        try database.writer.write { db in
            var r = try LibraryItemRecord.fetchOne(db, key: itemId)
                ?? LibraryItemRecord(itemId: itemId, status: status, startedAt: ms, updatedAt: ms)
            r.status = status
            r.updatedAt = ms
            r.finishedAt = status == .finished ? ms : nil
            r.abandonReason = status == .abandoned ? reason : nil
            try r.save(db)
        }
    }

    // MARK: Reading log

    /// Logs a session. `pages` estimate the words; pace is stored only with comprehension ≥ 70%.
    @discardableResult
    public func logReading(itemId: String, minutes: Int, pages: Int? = nil, words: Int? = nil,
                           comprehension: Double? = nil, note: String? = nil, now: Date) throws -> ReadingLogRecord {
        let estimated = words ?? pages.map { $0 * ReadingCheck.wordsPerPage }
        var log = ReadingLogRecord(
            ts: now.unixMilliseconds, day: DayBoundary.day(for: now, calendar: calendar), itemId: itemId,
            minutes: minutes, pages: pages, words: estimated,
            wpm: ReadingCheck.wpm(words: estimated, minutes: minutes, comprehension: comprehension),
            comprehension: comprehension, note: note)
        try database.writer.write { db in try log.insert(db) }
        return log
    }

    public func recentLogs(limit: Int = 20) throws -> [ReadingLogRecord] {
        try database.reader.read { try ReadingLogRecord.order(Column("ts").desc, Column("id").desc).limit(limit).fetchAll($0) }
    }

    /// Minutes logged in the 7 learning days ending `today` (Brain bites included).
    public func minutesLast7(today: Int) throws -> Int {
        let from = LearningDays.adding(-6, to: today)
        return try database.reader.read {
            try Int.fetchOne($0, sql: "SELECT COALESCE(SUM(minutes), 0) FROM reading_log WHERE day >= ? AND day <= ?",
                             arguments: [from, today]) ?? 0
        }
    }

    // MARK: Brain bites

    public func saveBrainBite(cardId: String, minutes: Int, answer: String?, now: Date) throws {
        let trimmed = answer?.trimmingCharacters(in: .whitespacesAndNewlines)
        try logReading(itemId: ReadingLogRecord.knowledgePrefix + cardId, minutes: minutes,
                       note: (trimmed?.isEmpty ?? true) ? nil : trimmed, now: now)
    }

    public func readKnowledgeIds() throws -> Set<String> {
        Set(try database.reader.read {
            try String.fetchAll($0, sql: "SELECT DISTINCT itemId FROM reading_log WHERE itemId LIKE ?",
                                arguments: [ReadingLogRecord.knowledgePrefix + "%"])
        }.map { String($0.dropFirst(ReadingLogRecord.knowledgePrefix.count)) })
    }

    // MARK: Deck picks

    public func pick(noteId: String, source: String, now: Date) throws {
        try database.writer.write { db in
            try DeckPickRecord(noteId: noteId, ts: now.unixMilliseconds, source: source).insert(db, onConflict: .ignore)
        }
    }

    public func pickedNoteIds() throws -> Set<String> {
        Set(try database.reader.read { try String.fetchAll($0, sql: "SELECT noteId FROM deck_pick") })
    }

    // MARK: Profile

    /// The recommender's view of the learner: history from `library_item`, pace from the median of their last
    /// five counted sessions (80...300 wpm), everything else the cold start.
    public func profile(level: Double = CEFRLevel.b1Plus.scaleValue) throws -> ReaderProfile {
        let rows = try items()
        let paces = try database.reader.read {
            try Double.fetchAll($0, sql: "SELECT wpm FROM reading_log WHERE wpm IS NOT NULL ORDER BY ts DESC LIMIT 5")
        }.sorted()
        var p = ReaderProfile(level: level, history: rows.map { ReadingHistoryEntry(itemId: $0.itemId, status: $0.status) })
        if !paces.isEmpty { p.wordsPerMinute = min(300, max(80, paces[paces.count / 2])) }
        return p
    }
}
