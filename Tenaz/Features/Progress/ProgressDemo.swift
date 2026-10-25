import Foundation
import GRDB
import TenazCore

/// Believable, deterministic data for snapshots and the `progress` selftest: the real engine and
/// stores on a throwaway in-memory database, driven by a manual clock through 12 learning days
/// (Mon 12 Oct to Fri 23 Oct 2026, Mexico City). Never touches the learner's database.
@MainActor
enum ProgressDemo {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return c
    }()

    struct Fixture {
        let engine: GamificationEngine
        let library: LibraryStore
        let weekly: WeeklyReviewStore
        let now: Date
        let today: Int
    }

    static let shared: Fixture? = {
        do { return try make() } catch {
            NSLog("Tenaz: progress demo failed: \(error)")
            return nil
        }
    }()

    static func date(_ day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100, hour: hour, minute: minute))!
    }

    static func make() throws -> Fixture {
        let root = Bundle.main.resourceURL!.appendingPathComponent("Content")
        let database = try TenazDatabase.inMemory()
        let vocab = ContentValidator.cleaned((try? ContentLibrary.load(from: root)) ?? ContentLibrary(vocab: [], items: [])).0.vocab
        try ContentImporter.importVocab(vocab, into: database, now: date(20260901, hour: 9))
        let clock = TestClock(date(20261012, hour: 9))
        let engine = try GamificationEngine.bundled(database: database, contentRoot: root, clock: clock, calendar: calendar)
        let library = LibraryStore(database: database, calendar: calendar)
        try engine.mergeStageEvidence { e in
            e.onboardingDone = true
            e.levelParagraphDone = true
            e.privateBand = StageEvidence.englishLevelPriorBand
        }

        // 12 days: two missed (Thu 15, Tue 20); today (Fri 23) half done.
        let missed: Set<Int> = [3, 8]
        var card = 0
        for offset in 0..<12 {
            let day = LearningDays.adding(offset, to: 20261012)
            clock.advance(by: date(day, hour: 9).timeIntervalSince(clock.now))
            if missed.contains(offset) { continue }
            let reviews = offset == 11 ? 7 : (offset == 6 ? 26 : 12)
            for i in 0..<reviews {
                try engine.handle(.reviewAnswered(AnsweredReview(cardId: "demo-\(card)", correct: offset == 6 || i % 9 != 4)))
                card += 1
            }
            if offset != 11 {
                try engine.handle(.productionDone(Production(refId: "demo-p\(offset)", quality: 0.7, words: 24)))
            }
            if offset == 2 { try library.setStatus("book-who-moved-my-cheese", .inProgress, now: clock.now) }
            if offset == 4 {
                try library.logReading(itemId: "book-who-moved-my-cheese", minutes: 20, pages: 18, comprehension: 1, now: clock.now)
                try library.setStatus("book-who-moved-my-cheese", .finished, now: clock.now)
            }
            if offset == 5 { try library.setStatus("book-the-giver", .inProgress, now: clock.now) }
            if [5, 7, 9, 10].contains(offset) {
                try library.logReading(itemId: "book-the-giver", minutes: [5: 15, 7: 12, 9: 20, 10: 15][offset]!, pages: 6,
                                       comprehension: offset == 7 ? 2.0 / 3 : 1, now: clock.now + 3600 * 10)
            }
        }
        try library.saveBrainBite(cardId: "kn-technical-debt", minutes: 2, answer: "We should refactor the export module.", now: clock.now - 86400 * 3)
        try library.saveBrainBite(cardId: "kn-if-then-plans", minutes: 2, answer: nil, now: clock.now - 86400)
        try library.logReading(itemId: "pod-bbc-6-minute-english", minutes: 6, now: clock.now - 86400 * 2)
        try library.pick(noteId: "tech-english-latency", source: "knowledge:kn-latency", now: clock.now)

        clock.advance(by: date(20261023, hour: 18, minute: 30).timeIntervalSince(clock.now))
        let now = clock.now
        let today = DayBoundary.day(for: now, calendar: calendar)
        try seedHistory(database, vocab: vocab, now: now, today: today)
        let weekly = WeeklyReviewStore(database: database, calendar: calendar)
        let mastered = try weekly.report(now: now, stages: engine.stages).masteredNow
        try engine.updateLearning(LearningSnapshot(notesIntroduced: 84, masteredNotes: mastered, dueCount: 12,
                                                   oldestOverdueHours: 3, weakestCategory: "articles"))
        return Fixture(engine: engine, library: library, weekly: weekly, now: now, today: today)
    }

    /// Review history (mastered growth), the error ledger, rule outcomes, hatches and an older review.
    private static func seedHistory(_ database: TenazDatabase, vocab: [VocabEntry], now: Date, today: Int) throws {
        let dayMs: Int64 = 86_400_000
        let nowMs = now.unixMilliseconds
        try database.writer.write { db in
            let cards = try Row.fetchAll(db, sql: "SELECT id, noteId, type FROM card").compactMap { row -> (id: String, noteId: String, type: CardType)? in
                guard let type = CardType(rawValue: row["type"]) else { return nil }
                return (row["id"], row["noteId"], type)
            }
            let primary = MasteryHistory.primaryCards(cards).sorted().prefix(52)
            for (j, cardId) in primary.enumerated() {
                // Each note's third good review (stability 26 d) lands on a different day: steady growth.
                let first = nowMs - Int64(46 - j - (j % 7 == 3 ? 4 : 0) + (j % 5 == 1 ? 3 : 0)) * dayMs + Int64(j % 5) * 3_600_000
                for (k, (offset, stability)) in [(0, 2.3), (2, 7.5), (7, 26.0), (30, 70.0)].enumerated() {
                    let ts = first + Int64(offset) * dayMs
                    guard ts < nowMs else { break }
                    try db.execute(sql: """
                        INSERT INTO review_log (cardId, ts, rating, stateBefore, stateAfter, sBefore, sAfter, elapsedDays,
                        scheduledDays, durationMs, inputMode, surface) VALUES (?, ?, 3, 'review', 'review', ?, ?, ?, ?, 4000, 'typed', 'session')
                        """, arguments: [cardId, ts, k == 0 ? nil : stability / 3, stability, Double(offset), stability])
                }
            }
            let ledger: [(String, String, String, Int, Int, Int)] = [
                ("articles", "I am engineer in a big company", "I am an engineer in a big company", 7, 20, 0),
                ("prepositions", "We discussed about the release", "We discussed the release", 5, 15, 1),
                ("presentPerfect", "I work here since 2022", "I have worked here since 2022", 3, 2, 0),
                ("falseFriends", "I assisted to the meeting", "I attended the meeting", 2, 25, 12),
            ]
            for (category, example, correction, count, firstAgo, lastAgo) in ledger {
                try db.execute(sql: "INSERT INTO error_ledger (category, example, correction, count, firstSeen, lastSeen) VALUES (?, ?, ?, ?, ?, ?)",
                               arguments: [category, example, correction, count, nowMs - Int64(firstAgo) * dayMs, nowMs - Int64(lastAgo) * dayMs - 3_600_000])
            }
            let rules: [(PenaltyRuleKind, PenaltyOutcome, Int)] = [
                (.responseCost, .fired, 1), (.responseCost, .fired, 3), (.responseCost, .escaped, 4),
                (.strictGate, .escaped, 1), (.strictGate, .escaped, 2), (.strictGate, .dismissed, 5),
                (.strictGate, .escaped, 9), (.strictGate, .escaped, 10),
            ]
            for (rule, outcome, ago) in rules {
                var e = PenaltyEventRecord(ruleId: rule.rawValue, ts: nowMs - Int64(ago) * dayMs, day: LearningDays.adding(-ago, to: today),
                                           cost: "none", outcome: outcome)
                try e.insert(db)
            }
            let hatches: [(HatchKind, Bool, Int)] = [
                (.killSwitch, false, 1), (.killSwitch, false, 4), (.snooze, false, 0), (.snooze, false, 2), (.snooze, false, 3),
                (.meetingClaim, true, 2), (.meetingClaim, false, 5), (.overlaySkip, false, 1),
            ]
            for (kind, corroborated, ago) in hatches {
                var h = HatchEventRecord(ts: nowMs - Int64(ago) * dayMs, kind: kind, corroborated: corroborated,
                                         day: LearningDays.adding(-ago, to: today))
                try h.insert(db)
            }
            var old = WeeklyReviewRecord(weekStart: LearningDays.adding(-14, to: LearningDays.weekStart(today)), createdAt: nowMs - 16 * dayMs,
                                         answers: "{\"rulesToRethink\":[],\"whatWorked\":\"Reviews on the bus\"}", automaticity: 3, hatchCounts: "{}")
            try old.insert(db)
            var plan = IfThenPlanRecord(cue: "I open my laptop after lunch", action: "I review 5 words", createdAt: nowMs - 16 * dayMs)
            try plan.insert(db)
        }
    }
}
