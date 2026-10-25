import Foundation
import Testing
@testable import TenazCore

struct ExamResumeTests {
    /// A placement paused between sections rebuilds to the same tasks, answers and section.
    @Test func pauseBetweenSectionsReplays() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = try ExamFixtures.session(.placement, clock: clock, seed: 3)
        try store.begin(session)
        var learner = SimulatedLearner(theta: 0, seed: 5)
        // Finish the first (vocabulary) section, then pause before the second.
        let first = session.currentSection?.id
        while let task = session.currentTask, task.sectionId == first {
            clock.advance(by: 10)
            session.answer(learner.answer(task))
            try store.recordResponse(session, taskId: task.id)
        }
        session.pause(.user)
        try store.saveProgress(session, pausedBetweenSections: true, at: clock.now)
        let expectedSection = session.sectionIndex
        let expectedTask = session.currentTask?.id

        let catalog = try BlueprintCatalog.load(from: ContentTests.contentRoot)
        let (restored, replay) = try store.restore(session.id, catalog: catalog, library: ExamFixtures.library)
        #expect(restored.sectionIndex == expectedSection)
        #expect(restored.currentTask?.id == expectedTask)
        #expect(restored.responses.map(\.taskId) == session.responses.map(\.taskId))
        #expect(restored.status == .paused(.user))
        replay.goLive()
        var resumed = restored
        resumed.resume()
        #expect(resumed.status == .running)
        #expect(try store.isResumable(try #require(try store.attempt(session.id)), now: clock.now.addingTimeInterval(86_400)))
    }

    /// A section ended early with no answers is skipped again on replay via the stored section index.
    @Test func emptyEndedSectionReplays() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = try ExamFixtures.session(.placement, clock: clock, seed: 9)
        try store.begin(session)
        session.endSection()
        session.endSection()
        try store.saveProgress(session, pausedBetweenSections: true, at: clock.now)
        let catalog = try BlueprintCatalog.load(from: ContentTests.contentRoot)
        let (restored, _) = try store.restore(session.id, catalog: catalog, library: ExamFixtures.library)
        #expect(restored.sectionIndex == session.sectionIndex)
        #expect(restored.currentTask?.id == session.currentTask?.id)
    }

    /// A weekly mock cut off by a crash resumes within 15 minutes and is abandoned after that.
    @Test func crashWindowForMocks() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = try ExamFixtures.session(.weekly, clock: clock)
        try store.begin(session)
        if let task = session.currentTask {
            session.answer(.gaps([]))
            try store.recordResponse(session, taskId: task.id)
        }
        try store.saveProgress(session, pausedBetweenSections: false, at: clock.now)
        let attempt = try #require(try store.attempt(session.id))
        #expect(try store.isResumable(attempt, now: clock.now.addingTimeInterval(10 * 60)))
        #expect(try !store.isResumable(attempt, now: clock.now.addingTimeInterval(20 * 60)))
        try store.abandon(session.id, at: clock.now)
        #expect(try store.unfinishedAttempts().isEmpty)
        #expect(try store.history().first?.status == "abandoned")
    }

    @Test func notesAccumulate() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let session = try ExamFixtures.session(.daily, clock: clock)
        try store.begin(session)
        try store.saveProgress(session, pausedBetweenSections: false, note: ("a", "readInstead"), at: clock.now)
        try store.saveProgress(session, pausedBetweenSections: false, note: ("b", "typedInstead"), at: clock.now)
        #expect(try store.progress(session.id)?.noteMap == ["a": "readInstead", "b": "typedInstead"])
    }

    @Test func mergeStageEvidenceKeepsOtherFields() throws {
        let engine = try GamificationEngine.bundled(database: .inMemory(), contentRoot: ContentTests.contentRoot)
        try engine.updateStageEvidence(StageEvidence(onboardingDone: true, privateBand: 3.5))
        try engine.mergeStageEvidence { $0.placementDone = true; $0.placementBand = 4.0 }
        let e = try engine.stageEvidence()
        #expect(e.onboardingDone && e.placementDone)
        #expect(e.privateBand == 3.5 && e.placementBand == 4.0)
    }
    @Test func currentBandIsTheLatestExamOverall() throws {
        let store = ExamStore(database: try .inMemory())
        #expect(try store.currentBand() == nil, "no exam yet: the Library keeps its B1+ default")
        func band(_ skill: String, _ value: Double, ts: Int64) throws {
            try store.database.writer.write { db in
                var r = BandHistoryRecord(id: nil, ts: ts, day: 20261023, attemptId: "a\(ts)", kind: "placement", skill: skill, band: value,
                                          low: value, high: value, thetaMean: value - 4, sd: 0.3, verified: true)
                try r.insert(db)
            }
        }
        try band(BandHistoryRecord.publicBand, 3.5, ts: 1)
        #expect(try store.currentBand() == 3.5)
        try band(BandHistoryRecord.overall, 4.0, ts: 2)
        try band(BandHistoryRecord.overall, 4.5, ts: 3)
        try band("reading", 5.0, ts: 4)
        #expect(try store.currentBand() == 4.5)
    }
}
