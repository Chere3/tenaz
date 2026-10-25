import Foundation
import GRDB
import Testing
@testable import TenazCore

struct ProgressStoreTests {
    static var calendar: Calendar { GamificationFixture.calendar }
    static func date(_ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100, hour: hour))!
    }

    @Test func migrationCreatesTablesOnce() throws {
        let db = try TenazDatabase.inMemory()
        let tables = try db.reader.read { try String.fetchAll($0, sql: "SELECT name FROM sqlite_master WHERE type = 'table'") }
        for t in ["reading_log", "library_item", "weekly_review", "if_then_plan", "deck_pick"] {
            #expect(tables.contains(t), "\(t)")
        }
    }

    @Test func libraryStoreLogsAndBuildsProfile() throws {
        let store = LibraryStore(database: try .inMemory(), calendar: Self.calendar)
        let now = Self.date(20261102)
        try store.setStatus("book-the-giver", .inProgress, now: now)
        // Understood: pace counts. Not understood: pace ignored.
        try store.logReading(itemId: "book-the-giver", minutes: 10, words: 2000, comprehension: 1, now: now)
        try store.logReading(itemId: "book-the-giver", minutes: 10, words: 4000, comprehension: 1.0 / 3, now: now)
        try store.saveBrainBite(cardId: "kn-latency", minutes: 2, answer: "  Our CI is the bottleneck. ", now: now)
        try store.pick(noteId: "tech-english-latency", source: "knowledge:kn-latency", now: now)
        try store.pick(noteId: "tech-english-latency", source: "knowledge:kn-latency", now: now)

        let profile = try store.profile()
        #expect(profile.history == [ReadingHistoryEntry(itemId: "book-the-giver", status: .inProgress)])
        #expect(profile.wordsPerMinute == 200)
        #expect(try store.readKnowledgeIds() == ["kn-latency"])
        #expect(try store.pickedNoteIds() == ["tech-english-latency"])
        #expect(try store.minutesLast7(today: 20261102) == 22)
        #expect(try store.recentLogs().first?.note == "Our CI is the bottleneck.")

        try store.setStatus("book-the-giver", .abandoned, reason: "boring", now: now + 60)
        let row = try #require(try store.items().first)
        #expect(row.status == .abandoned && row.abandonReason == "boring" && row.finishedAt == nil)
    }

    @Test func masteryHistoryCountsPrimaryCards() throws {
        let config = try StageConfig.load(from: ContentTests.contentRoot.appendingPathComponent("config/stages.json"))
        let primary = MasteryHistory.primaryCards([
            (id: "n1:R", noteId: "n1", type: .recognition), (id: "n1:L", noteId: "n1", type: .recall),
            (id: "n2:C", noteId: "n2", type: .cloze), (id: "n2:R", noteId: "n2", type: .recognition),
        ])
        #expect(primary == ["n1:L", "n2:C"])
        let day: Int64 = 86_400_000
        let reviews = [
            MasteryHistory.Review(cardId: "n1:L", ts: 1 * day, rating: 3, stability: 3),
            MasteryHistory.Review(cardId: "n1:L", ts: 2 * day, rating: 3, stability: 10),
            MasteryHistory.Review(cardId: "n1:L", ts: 3 * day, rating: 3, stability: 30),
            MasteryHistory.Review(cardId: "n1:R", ts: 3 * day, rating: 3, stability: 90), // not primary
            MasteryHistory.Review(cardId: "n1:L", ts: 5 * day, rating: 1, stability: 4),  // lapse
        ]
        let series = MasteryHistory.series(primary: primary, reviews: reviews,
                                           dayEnds: [2 * day + 1, 3 * day + 1, 4 * day + 1, 5 * day + 1], config: config)
        #expect(series == [0, 1, 1, 0])
    }

    @Test func weeklyReviewReportsAndSaves() throws {
        let fx = try GamificationFixture()
        let db = fx.engine.database
        let store = WeeklyReviewStore(database: db, calendar: GamificationFixture.calendar)
        // Two qualified days in the last week.
        for _ in 0..<2 {
            try fx.qualifyToday()
            fx.advance(days: 1)
        }
        try db.writer.write { db in
            let now = fx.clock.now.unixMilliseconds
            try db.execute(sql: "INSERT INTO error_ledger (category, example, correction, count, firstSeen, lastSeen) VALUES ('articles', 'I am engineer', 'I am an engineer', 3, ?, ?)",
                           arguments: [now - 3_600_000, now])
            // What IntrusionCoordinator writes: one hatch_event per use, plus how the surface ended.
            for kind: HatchKind in [.killSwitch, .killSwitch, .pause1h, .snooze, .overlaySkip, .emergencySkip] {
                var h = HatchEventRecord(ts: now, kind: kind, day: fx.today)
                try h.insert(db)
            }
            var corroborated = HatchEventRecord(ts: now, kind: .meetingClaim, corroborated: true, day: fx.today)
            try corroborated.insert(db)
            var claim = HatchEventRecord(ts: now, kind: .joiningCall, corroborated: false, day: fx.today)
            try claim.insert(db)
            var old = HatchEventRecord(ts: now, kind: .killSwitch, day: LearningDays.adding(-9, to: fx.today))
            try old.insert(db)
            // A pause and an app quit also close surfaces as "killed": not kill-switch uses.
            for reason in ["paused 1 h", "app quit", "kill switch: hotkey (until 04:00)"] {
                try db.execute(sql: "INSERT INTO intrusion_log (ts, surface, trigger, decision, reason, outcome) VALUES (?, 'overlay', 'test', 'allow', ?, 'killed')",
                               arguments: [now, reason])
            }
            var e = PenaltyEventRecord(ruleId: PenaltyRuleKind.strictGate.rawValue, ts: now, day: fx.today, cost: "none", outcome: .escaped)
            try e.insert(db)
        }
        let config = fx.engine.stages
        let report = try store.report(now: fx.clock.now, stages: config)
        #expect(report.last7.count == 7)
        #expect(report.daysPracticed7 == 2)
        #expect(report.masteredSeries.count == 30)
        #expect(report.errors.first?.category == "articles" && report.errors.first?.isNew == true)
        #expect(report.hatches.killSwitch == 2 && report.hatches.asksRenegotiation, "only this week's hatch_event rows count")
        #expect(report.hatches.pause == 1 && report.hatches.snoozes == 1 && report.hatches.skips == 1)
        #expect(report.hatches.meetingClaims == 1 && report.hatches.uncorroboratedClaims == 1)
        #expect(report.hatches.emergencySkips == 1)
        #expect(report.rules.map(\.rule) == [PenaltyRuleKind.strictGate.rawValue])
        #expect(report.rules.first?.stats.escapeRate == 1)
        #expect(report.automaticityDue && report.saved == nil)

        let saved = try store.save(report: report, answers: WeeklyReviewAnswers(whatWorked: "Reviews after lunch"),
                                   automaticity: 5, plan: (cue: "I unlock after lunch", action: "I review 3 words"), now: fx.clock.now)
        #expect(saved.automaticity == 5)
        let again = try store.report(now: fx.clock.now, stages: config)
        #expect(again.saved?.id == saved.id)
        #expect(again.plans.map(\.sentence) == ["If I unlock after lunch, then I review 3 words."])
        #expect(!again.automaticityDue)
        // One week later the automaticity question is still not due; two weeks later it is.
        fx.advance(days: 7)
        #expect(!(try store.report(now: fx.clock.now, stages: config).automaticityDue))
        fx.advance(days: 7)
        #expect(try store.report(now: fx.clock.now, stages: config).automaticityDue)
    }

    @Test func onlyThreePlansStayActive() throws {
        let store = WeeklyReviewStore(database: try .inMemory(), calendar: Self.calendar)
        let config = try StageConfig.load(from: ContentTests.contentRoot.appendingPathComponent("config/stages.json"))
        var now = Self.date(20261102)
        for i in 0..<5 {
            let report = try store.report(now: now, stages: config)
            try store.save(report: report, answers: WeeklyReviewAnswers(), automaticity: nil, plan: (cue: "cue \(i)", action: "act"), now: now)
            now += 7 * 86400
        }
        let plans = try store.report(now: now, stages: config).plans
        #expect(plans.map(\.cue) == ["cue 4", "cue 3", "cue 2"])
    }

    @Test func onboardingPlanAndWeeklyPlansShareTheTable() throws {
        let store = WeeklyReviewStore(database: try .inMemory(), calendar: Self.calendar)
        let config = try StageConfig.load(from: ContentTests.contentRoot.appendingPathComponent("config/stages.json"))
        let now = Self.date(20261102)
        // Onboarding writes the first plan; the weekly review lists it and adds to the same table.
        try store.addPlan(cue: " I finish lunch ", action: "I do my Tenaz set", now: now)
        #expect(try store.addPlan(cue: "", action: "nothing", now: now) == nil)
        let report = try store.report(now: now + 60, stages: config)
        #expect(report.plans.map(\.sentence) == ["If I finish lunch, then I do my Tenaz set."])
        try store.save(report: report, answers: WeeklyReviewAnswers(), automaticity: nil,
                       plan: (cue: "a meeting ends", action: "I write down 1 phrase"), now: now + 120)
        #expect(try store.report(now: now + 180, stages: config).plans.map(\.cue) == ["a meeting ends", "I finish lunch"])
    }
}
