import Foundation
import Testing
@testable import TenazCore

struct GateTests {
    typealias F = IntrusionFixture
    let paragraph = "This morning I have to follow up on the bug that broke our login page yesterday. "
        + "After that I will review two pull requests, and then I want to finish my English practice before lunch with the team."

    @Test func localChecksPassGoodParagraph() {
        let r = GateChecker.check(paragraph, chunk: "follow up on")
        #expect(r.words >= 25)
        #expect(r.englishOK)
        #expect(r.chunkPresent)
        #expect(r.varietyOK)
        #expect(r.passes)
    }

    @Test func localChecks() {
        // Too short.
        #expect(!GateChecker.check("I will follow up on it today.", chunk: "follow up on").lengthOK)
        // Spanish is rejected.
        let spanish = "Esta mañana tengo que dar seguimiento al error que rompió la página de inicio ayer y después revisar dos solicitudes de cambios antes de comer con el equipo de trabajo hoy."
        #expect(!GateChecker.check(spanish, chunk: nil).englishOK)
        // Missing chunk is rejected.
        #expect(!GateChecker.check(paragraph, chunk: "leverage").chunkPresent)
        // Repeating one word fails the variety floor.
        let repeated = Array(repeating: "very good", count: 15).joined(separator: " ")
        #expect(!GateChecker.check(repeated, chunk: nil).varietyOK)
    }

    @Test func chunkIsLemmaTolerant() {
        #expect(GateChecker.contains("Yesterday I followed up on the email.", chunk: "follow up on"))
        #expect(GateChecker.contains("She is leveraging our data.", chunk: "leverage"))
        #expect(GateChecker.contains("I managed to finish it.", chunk: "manage to"))
        #expect(!GateChecker.contains("I followed the plan up.", chunk: "follow up on"))
    }

    @Test func maxThreePerDayTwoHoursApart() {
        let first = F.date(2, 8, 30)
        #expect(F.decide(F.request(.gate, at: first)) == .show(.poster))
        #expect(F.decide(F.request(.gate, at: F.date(2, 9, 30)) { $0.history = IntrusionHistory(shown: [first]) }) != .show(.poster))
        #expect(F.decide(F.request(.gate, at: F.date(2, 10, 31)) { $0.history = IntrusionHistory(shown: [first]) }) == .show(.poster))
    }

    @Test func eligibilityNeedsThirtyMinutesOrFirstUnlock() {
        let now = F.date(2, 15)
        #expect(GateEligibility.qualifies(lockedSince: nil, now: now, lastUnlock: F.date(1, 22), calendar: F.calendar))
        #expect(!GateEligibility.qualifies(lockedSince: now.addingTimeInterval(-600), now: now, lastUnlock: F.date(2, 9), calendar: F.calendar))
        #expect(GateEligibility.qualifies(lockedSince: now.addingTimeInterval(-1900), now: now, lastUnlock: F.date(2, 9), calendar: F.calendar))
    }

    @Test func idleTimeoutIsFreeAndRetried() throws {
        let store = IntrusionStore(database: try .inMemory())
        try store.log(IntrusionLogRecord(ts: IntrusionStore.ms(F.now), surface: .gate, trigger: .unlock, decision: "allow",
                                         reason: nil, outcome: .timeoutIdle))
        try store.log(IntrusionLogRecord(ts: IntrusionStore.ms(F.now), surface: .gate, trigger: .unlock, decision: "allow",
                                         reason: nil, outcome: .deferredMidway))
        #expect(try store.history(.gate, now: F.now).shown.isEmpty)
        try store.log(IntrusionLogRecord(ts: IntrusionStore.ms(F.now), surface: .gate, trigger: .unlock, decision: "allow",
                                         reason: nil, outcome: .timeoutAbandoned))
        #expect(try store.history(.gate, now: F.now).shown.count == 1)
    }

    @Test func promptPicksForgottenWordFirst() throws {
        let items = try ContentLibrary.load(from: ContentTests.contentRoot).items
        var rng = SeededRandom(seed: 20261102)
        let p = GatePrompt.pick(items: items, history: [], pendingId: nil, now: F.now, forgottenWords: ["reliable"], rng: &rng)
        #expect(p.chunk == "reliable" && p.chunkIsForgottenWord)
        let q = GatePrompt.pick(items: items, history: [], pendingId: nil, now: F.now, forgottenWords: [], rng: &rng)
        #expect(!q.chunk.lowercased().hasPrefix("use "))
        #expect(!q.question.isEmpty)
    }

    @Test func acceptedParagraphQueuesClaudeGrade() throws {
        let db = try TenazDatabase.inMemory()
        let store = IntrusionStore(database: db)
        let prompt = GatePrompt(id: "life-paragraphs-001", question: "What is your plan today?", chunk: "follow up on")
        let id = try store.saveGateParagraph(prompt: prompt, text: paragraph, checks: GateChecker.check(paragraph, chunk: "follow up on"), at: F.now)
        let entry = try #require(try ExamStore(database: db).writingEntry(id))
        #expect(entry.surface == "gate" && entry.gradeStatus == "pending")
        let job = try #require(try ExamStore(database: db).claimNextJob(now: F.now.addingTimeInterval(1)))
        #expect(job.payload.entryId == id && job.payload.runs == 1)
    }
}
