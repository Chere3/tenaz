import Foundation
import GRDB
import Testing
@testable import TenazCore

/// The scheduling migration (PLAN §4.3, M2).
struct MigrationTests {
    func columns(_ db: Database, _ table: String) throws -> Set<String> {
        Set(try db.columns(in: table).map(\.name))
    }

    @Test func freshAndUpgrade() throws {
        // Fresh: everything at once.
        let fresh = try TenazDatabase.inMemory()
        try fresh.reader.read { (db: Database) throws in
            #expect(try columns(db, "note") == ["id", "kind", "display", "lemma", "glossEs", "exampleEn", "exampleEs", "cefr", "freqRank", "tags", "mustKnow", "source", "sourceRef", "suspended"])
            #expect(try columns(db, "card") == ["id", "noteId", "type", "state", "step", "due", "stability", "difficulty", "reps", "lapses", "lastReview", "desiredRetention", "leech", "buriedUntilDay"])
            #expect(try columns(db, "review_log") == ["id", "cardId", "ts", "rating", "stateBefore", "stateAfter", "sBefore", "sAfter", "dBefore", "dAfter", "elapsedDays", "scheduledDays", "durationMs", "inputMode", "surface", "answerText", "appFocusOk"])
        }

        // Upgrade: a database that only has v1, with data, then the full migrator.
        let queue = try DatabaseQueue()
        try Migrations.migrator().migrate(queue, upTo: "v1_base")
        try queue.write { try $0.execute(sql: "INSERT INTO app_meta (key, value) VALUES ('k', 'v')") }
        #expect(try queue.read { try $0.tableExists("card") } == false)
        let upgraded = try TenazDatabase(writer: queue)
        try upgraded.reader.read { (db: Database) throws in
            for table in ["note", "card", "review_log"] { #expect(try db.tableExists(table)) }
            #expect(try String.fetchOne(db, sql: "SELECT value FROM app_meta WHERE key = 'k'") == "v")
            #expect(try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations").contains("v2_scheduling"))
        }
    }

    @Test func recordsRoundTrip() throws {
        let db = try TenazDatabase.inMemory()
        let note = QueueFixture.note("n", kind: .chunk, tag: "meetings", mustKnow: true)
        var card = QueueFixture.reviewCard("n", .recall)
        try db.writer.write { db in
            try note.insert(db)
            try card.insert(db)
        }
        card.lapses = 2
        let after = card
        var log = ReviewLogRecord(before: card, after: after, rating: .good, at: QueueFixture.now, durationMs: 1234, inputMode: .typed, surface: .gate, answerText: "x")
        try db.writer.write { db in
            try after.update(db)
            try log.insert(db)
        }
        try db.reader.read { (db: Database) throws in
            #expect(try NoteRecord.fetchOne(db, key: "n") == note)
            #expect(try CardRecord.fetchOne(db, key: "n:L") == after)
            #expect(try ReviewLogRecord.fetchOne(db)?.surface == .gate)
        }
        #expect(log.id != nil)
    }
}
