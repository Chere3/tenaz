import Foundation
import GRDB
@testable import TenazCore
import Testing

/// `ReviewStore.learningSnapshot`: the counts Home sends to the gamification engine.
struct LearningSnapshotTests {
    typealias F = QueueFixture
    let stages = StageConfig(version: 1, mastered: .init(minStabilityDays: 21, lastCorrectRecalls: 3),
                             microGrowthEvery: 25, cosmeticWeeks: [], stages: [])

    func log(_ card: CardRecord, _ rating: Rating, minutesAgo: Double, _ db: Database) throws {
        var row = ReviewLogRecord(before: card, after: card, rating: rating, at: F.now.addingTimeInterval(-minutesAgo * 60),
                                  durationMs: 1000, inputMode: .typed, surface: .session, answerText: nil)
        try row.insert(db)
    }

    @Test func masteredCountsThePrimaryCardOnlyAndNeedsThreeRightRecalls() throws {
        let db = try TenazDatabase.inMemory()
        try db.writer.write { db in
            for id in ["a", "b", "c", "d"] {
                try F.note(id).insert(db)
            }
            // a: stable L with 3 right recalls -> mastered (its stable C must not count twice).
            let aL = F.reviewCard("a", .recall, stability: 30, dueOffset: 86400 * 20)
            let aC = F.reviewCard("a", .cloze, stability: 40, dueOffset: 86400 * 20)
            try aL.insert(db); try aC.insert(db)
            for m in [30.0, 20, 10] {
                try log(aL, .good, minutesAgo: m, db)
            }
            // b: stable L, but the latest recall was wrong -> not mastered.
            let bL = F.reviewCard("b", .recall, stability: 25, dueOffset: 86400 * 20)
            try bL.insert(db)
            for (m, r) in [(30.0, Rating.good), (20, .good), (10, .again)] {
                try log(bL, r, minutesAgo: m, db)
            }
            // c: no L, stable C with 3 right -> mastered.
            let cC = F.reviewCard("c", .cloze, stability: 22, dueOffset: 86400 * 20)
            try cC.insert(db)
            for m in [3.0, 2, 1] {
                try log(cC, .hard, minutesAgo: m, db)
            }
            // d: overdue by 2 hours, unstable.
            let dC = F.reviewCard("d", .cloze, stability: 3, dueOffset: -7200)
            try dC.insert(db)
            try log(dC, .good, minutesAgo: 600, db)
        }
        let s = try ReviewStore(database: db).learningSnapshot(now: F.now, stages: stages)
        #expect(s.masteredNotes == 2)
        #expect(s.notesIntroduced == 4)
        #expect(s.dueCount == 1)
        #expect(abs(s.oldestOverdueHours - 2) < 0.01)
    }

    @Test func freshDatabaseIsAllZero() throws {
        let s = try ReviewStore(database: TenazDatabase.inMemory()).learningSnapshot(now: F.now, stages: stages)
        #expect(s == LearningSnapshot())
    }
}
