import Foundation
import GRDB
import Testing
@testable import TenazCore

struct ExamTests {
    // MARK: Estimation

    @Test func raschPosteriorMovesTowardEvidence() {
        let prior = AbilityEstimator()
        var up = prior
        up.update(correct: true, difficulty: 1.0, guessing: 0.25)
        #expect(up.mean > prior.mean)

        var down = prior
        down.update(correct: false, difficulty: -1.0)
        #expect(down.mean < prior.mean)

        // Consistent evidence near the estimate shrinks the SD.
        var steady = prior
        for i in 0..<20 { steady.update(correct: i % 2 == 0, difficulty: -0.3) }
        #expect(steady.sd < 0.6)
        #expect(abs(steady.mean - prior.mean) < 0.2)

        // A rubric score is evidence toward its mapped theta (5 of 5 ≈ C1).
        var rubric = prior
        rubric.update(rubric: 5)
        #expect(rubric.mean > 0.5)

        // Daily evidence (weight 0.5) moves the posterior less than a mock's (1.0).
        var mock = prior
        mock.update(correct: true, difficulty: 1.0, weight: ExamKind.weekly.evidenceWeight)
        var daily = prior
        daily.update(correct: true, difficulty: 1.0, weight: ExamKind.daily.evidenceWeight)
        #expect(prior.mean < daily.mean && daily.mean < mock.mean)
    }

    @Test func posteriorBlobRoundTrips() throws {
        var est = AbilityEstimator()
        est.update(correct: true, difficulty: 0.5)
        let back = try #require(AbilityEstimator(blob: est.blob))
        #expect(back == est)
        #expect(AbilityEstimator(blob: Data([1, 2, 3])) == nil)
    }

    @Test func stopsWhenSDBelowThreshold() throws {
        let blueprint = try ExamFixtures.blueprint(.daily)
        let rule = try #require(blueprint.sections.first { $0.adaptive != nil }?.adaptive)

        // Tight stored posteriors (SD < 0.35): the adaptive section stops at its minimum.
        var tight = AbilityEstimator(priorMean: 0, priorSD: 0.25)
        tight.update(correct: true, difficulty: 0)
        #expect(tight.sd < rule.stopSD)
        let tightPriors = Dictionary(uniqueKeysWithValues: ExamSkill.allCases.map { ($0, tight) })
        let clock = TestClock()
        var session = ExamSession(blueprint: blueprint, library: ExamFixtures.library, priors: tightPriors, seed: 11, clock: clock)
        var learner = SimulatedLearner(theta: 0, seed: 1)
        learner.take(&session, clock: clock)
        let adaptive = session.tasks.filter { $0.sectionId == "mixed" }
        #expect(adaptive.count == rule.min)

        // Day-one priors (SD 1.0) never get below 0.35 at weight 0.5: it runs to the maximum.
        let clock2 = TestClock()
        var wide = try ExamFixtures.session(.daily, clock: clock2, seed: 11)
        var learner2 = SimulatedLearner(theta: 0, seed: 1)
        learner2.take(&wide, clock: clock2)
        #expect(wide.tasks.filter { $0.sectionId == "mixed" }.count == rule.max)
        #expect(wide.isComplete)
        // 12-20 items in all, as PLAN F5 says.
        #expect((12...20).contains(session.tasks.count))
        #expect((12...20).contains(wide.tasks.count))
    }

    @Test func bandNeverRoundsUp() {
        #expect(AbilityEstimator.band(for: 0.49) == 4.0)
        #expect(AbilityEstimator.band(for: -0.01) == 3.5)
        #expect(OverallBand.average([3.5, 4, 4, 4]) == 4.0) // 3.875 → 4.0 (nearest)
        #expect(OverallBand.average([3.5, 3.5, 4, 4]) == 3.5) // 3.75 tie → down
        #expect(OverallBand.average([3.5, 3.0, 3.5, 3.5]) == 3.5) // 3.375 → 3.5
        #expect(OverallBand.average([4, 4, 4, 4.5]) == 4.0) // 4.125 → 4.0
        #expect(OverallBand.average([4.5, 4.5, 4.5, 4.5]) == 4.5)
        var est = AbilityEstimator(priorMean: 0.45, priorSD: 0.3)
        est.update(correct: true, difficulty: 0)
        #expect(est.bandRange.lowerBound <= est.band && est.band <= est.bandRange.upperBound)
        #expect(OverallBand(estimates: [:]).band == 3.5) // all priors at B1+
    }

    @Test func buildSentenceAcceptsListedOrders() throws {
        let item = try ExamFixtures.item("""
            {"id": "t-build", "type": "buildSentence", "cefr": "B2", "context": "When can we meet?",
             "chunks": ["tomorrow", "we could", "meet", "after lunch"],
             "answer": "We could meet tomorrow after lunch.", "accepted": ["We could meet after lunch tomorrow."]}
            """)
        #expect(ObjectiveScorer.scoreBuildSentence(item, attempt: "we could meet tomorrow after lunch"))
        #expect(ObjectiveScorer.scoreBuildSentence(item, attempt: "We could meet after lunch tomorrow."))
        #expect(!ObjectiveScorer.scoreBuildSentence(item, attempt: "Tomorrow we could meet after lunch."))
        let task = ExamTask(content: .item(item), sectionId: "s", skill: .grammar)
        #expect(ObjectiveScorer.units(for: task, answer: .text("We could meet after lunch tomorrow.")).map(\.isCorrect) == [true])
        #expect(ObjectiveScorer.units(for: task, answer: nil).map(\.isCorrect) == [false])
    }

    // MARK: Session state machine

    @Test func meetingPausesExam() throws {
        let clock = TestClock()
        var session = try ExamFixtures.session(.daily, clock: clock)
        clock.advance(by: 30)
        let remaining = session.sectionRemaining
        let task = session.currentTask?.id
        session.pause(.meeting)
        #expect(session.status == .paused(.meeting))
        clock.advance(by: 600)
        let r1 = session.answer(.choices([0]))
        #expect(!r1)
        let r2 = session.tick()
        #expect(!r2)
        #expect(session.sectionRemaining == remaining)
        #expect(session.currentTask?.id == task)
        session.resume()
        #expect(session.status == .running)
        #expect(session.pausedMs == 600_000)
        clock.advance(by: 10)
        let r3 = session.answer(.gaps([]))
        #expect(r3)
        #expect(session.response(for: task ?? "")?.latencyMs == 40_000) // paused time is not latency
    }

    @Test func sectionTimerEndsSection() throws {
        let clock = TestClock()
        var session = try ExamFixtures.session(.daily, clock: clock)
        let first = try #require(session.currentSection)
        clock.advance(by: first.minutes * 60 - 1)
        let r4 = session.tick()
        #expect(!r4)
        clock.advance(by: 2)
        let r5 = session.tick()
        #expect(r5)
        #expect(session.currentSection?.id != first.id)
    }

    @Test func abortVoidsAttempt() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = try ExamFixtures.session(.daily, clock: clock)
        try store.begin(session)
        let taskId = try #require(session.currentTask?.id)
        session.answer(.gaps(["x"]))
        try store.recordResponse(session, taskId: taskId)
        session.abort()
        #expect(session.status == .voided)
        let r6 = session.submit()
        #expect(r6 == nil)
        let r7 = session.answer(.choices([0]))
        #expect(!r7)
        try store.void(session)

        #expect(try store.attempt(session.id)?.status == "void")
        let sources = try store.database.reader.read {
            try String.fetchAll($0, sql: "SELECT scoreSource FROM exam_response WHERE attemptId = ?", arguments: [session.id])
        }
        #expect(!sources.isEmpty && sources.allSatisfy { $0 == "void" })
        let states = try store.database.reader.read { try SkillStateRecord.fetchCount($0) }
        #expect(states == 0)
        #expect(try store.bands(attemptId: session.id).isEmpty)
    }

    @Test func responsesAreWrittenAsSoonAsAnswered() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = try ExamFixtures.session(.daily, clock: clock)
        try store.begin(session, mockGroupId: nil)
        let taskId = try #require(session.currentTask?.id)
        session.answer(.gaps(["a", "b"]))
        try store.recordResponse(session, taskId: taskId)
        try store.recordResponse(session, taskId: taskId) // idempotent
        let rows = try store.database.reader.read {
            try ExamResponseRecord.filter(Column("attemptId") == session.id).fetchAll($0)
        }
        #expect(rows.count == 1)
        #expect(rows.first?.scoreSource == "pending")
        #expect(rows.first?.answer?.contains("\"a\"") == true)
        let attempt = try #require(try store.attempt(session.id))
        #expect(attempt.priors?.count == ExamSkill.allCases.count * AbilityEstimator.grid.count * 8)
        #expect(attempt.excluded == "[]")
    }

    @Test func routerSendsStrongLearnerToUpperModule() throws {
        let clock = TestClock()
        var strong = try ExamFixtures.session(.weekly, clock: clock)
        var learner = SimulatedLearner(theta: 4, seed: 2)
        learner.take(&strong, clock: clock)
        #expect(strong.routes["reading"] == .upper)
        #expect(strong.tasks.contains { $0.sectionId == "reading-upper" })
        #expect(!strong.tasks.contains { $0.sectionId == "reading-lower" })

        var weak = try ExamFixtures.session(.weekly, clock: clock)
        var learner2 = SimulatedLearner(theta: -4, seed: 2)
        learner2.take(&weak, clock: clock)
        #expect(weak.routes["reading"] == .lower)
        #expect(weak.routes["listening"] == .lower)
    }

    @Test func monthlyFollowsTOEFLStructure() throws {
        let monthly = try ExamFixtures.blueprint(.monthly)
        let ids = monthly.sections.map(\.id)
        #expect(ids.starts(with: ["reading-router", "reading-lower", "reading-upper", "listening-router"]))
        #expect(monthly.sections.contains { $0.id == "grammar-vocab" && $0.isOptional })
        let clock = TestClock()
        var session = try ExamFixtures.session(.monthly, clock: clock)
        var learner = SimulatedLearner(theta: 0.5, seed: 5)
        learner.take(&session, clock: clock)
        #expect(!session.tasks.contains { $0.sectionId == "grammar-vocab" }) // optional, not chosen
        let submitted = session.submit()
        let outcome = try #require(submitted)
        #expect(Set(outcome.pendingSkills) == [.writing, .speaking])
        #expect(outcome.overallIsProvisional)
    }

    /// Per skill, ~20 multiple-choice units leave SD ≈ 0.5, so single runs miss by a band now and
    /// then; across seeds the overall band must land within ±0.5 of the truth most of the time,
    /// never above it (bands are floored), and the objective estimates must be roughly unbiased.
    @Test func placementSimulationLandsNearTruth() async throws {
        let blueprint = try ExamFixtures.blueprint(.placement)
        var hits = 0
        var means: [ExamSkill: [Double]] = [:]
        let seeds = UInt64(1)...30
        for seed in seeds {
            let r = try await PlacementSimulation.run(theta: 0.3, seed: seed, blueprint: blueprint, library: ExamFixtures.library)
            if r.withinHalfBand { hits += 1 }
            #expect(r.overall.band <= r.truthBand + 0.5)
            #expect(r.recordedOverall == r.overall.band)
            #expect(Set(r.pendingBeforeGrading) == [.writing, .speaking])
            for skill in [ExamSkill.reading, .listening, .grammar] { means[skill, default: []].append(r.final[skill]?.mean ?? 0) }
        }
        #expect(hits >= 27, "hits \(hits)/30")
        for (skill, values) in means {
            let mean = values.reduce(0, +) / Double(values.count)
            #expect(abs(mean - 0.3) < 0.35, "\(skill) mean \(mean)")
        }
    }

    @Test func placementGrantsStatesAndPublicBand() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        #expect(try store.publicBand() == nil)
        let clock = TestClock()
        var session = try ExamFixtures.session(.placement, clock: clock)
        try store.begin(session)
        var learner = SimulatedLearner(theta: 0, seed: 9)
        learner.take(&session, clock: clock)
        let submitted = session.submit()
        let outcome = try #require(submitted)
        let jobs = try store.save(session, outcome: outcome)
        #expect(jobs.count == 3) // email, about-you, interview
        let states = try store.database.reader.read { try SkillStateRecord.fetchCount($0) }
        #expect(states == ExamSkill.allCases.count)
        // Grades pending: no overall band and no public band yet.
        #expect(try store.publicBand() == nil)
        #expect(try store.attempt(session.id)?.status == "done")
        // The next attempt starts from the granted states, not the day-one prior.
        #expect(try store.priors(for: .daily)[.reading]?.posterior == outcome.estimates[.reading]?.posterior)
    }

    @Test func emptyWritingScoresZeroLocally() throws {
        let clock = TestClock()
        var session = ExamSession(blueprint: ExamFixtures.emailOnly(.weekly), library: ExamFixtures.library,
                                  priors: ExamFixtures.priors(), seed: 1, clock: clock)
        session.answer(.text("   "))
        let submitted = session.submit()
        let outcome = try #require(submitted)
        #expect(outcome.pending.isEmpty)
        #expect(outcome.taskScores.first?.source == "local")
        #expect((outcome.estimates[.writing]?.mean ?? 0) < AbilityEstimator().mean)
    }

    // MARK: Grading pipeline

    @Test func monthlyMedianOfThree() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (session, jobs) = try ExamFixtures.submittedEmail(.monthly, store: store, clock: clock)
        #expect(jobs.count == 1)
        let runner = FakeGradeRunner(results: [
            ExamFixtures.writingGrade([3, 3, 4, 4], errors: [GradeError(span: "depends of", category: "preposition",
                                                                         correction: "depends on", ruleShort: "depend on")]),
            ExamFixtures.writingGrade([4, 4, 3, 3]),
            ExamFixtures.writingGrade([4, 3, 4, 3]),
        ])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        let report = await queue.drain()
        #expect(report.graded == jobs)
        #expect(await runner.calls == 3)

        let runs = try await store.database.reader.read { try GradeRunRecord.fetchAll($0) }
        #expect(runs.count == 12)
        #expect(Set(runs.map(\.runIndex)) == [0, 1, 2])
        let entryId = try #require(runs.first?.targetId)
        let entry = try #require(try store.writingEntry(entryId))
        #expect(entry.gradeStatus == "graded")
        let grade = try #require(ExamStore.decode(WritingGrade.self, entry.gradeJSON))
        #expect(grade.medians == ["task_fulfilment": 4, "organization_cohesion": 3, "grammar_accuracy": 4, "lexical_range": 3])
        #expect(grade.score == 3.5)
        #expect(grade.lowConfidence == false)
        #expect(try store.job(jobs[0])?.status == "done")

        let ledger = try await store.database.reader.read { try ErrorLedgerRecord.fetchAll($0) }
        #expect(ledger.map(\.example) == ["depends of"])
        // Writing posterior moved and the attempt finalized with an overall band.
        #expect(try store.skillStates()[.writing] != AbilityEstimator())
        #expect(try store.bands(attemptId: session.id).contains { $0.skill == BandHistoryRecord.overall })
    }

    @Test func spreadRunsAddTwoMoreAndFlag() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        _ = try ExamFixtures.submittedEmail(.monthly, store: store, clock: clock)
        let runner = FakeGradeRunner(results: [
            ExamFixtures.writingGrade([1, 3, 3, 3]), ExamFixtures.writingGrade([4, 3, 3, 3]), ExamFixtures.writingGrade([3, 3, 3, 3]),
        ])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        await queue.drain()
        #expect(await runner.calls == 5)
        let entry = try #require(try store.writingEntry(1))
        #expect(ExamStore.decode(WritingGrade.self, entry.gradeJSON)?.lowConfidence == true)
    }

    @Test func retriedMonthlyStillAddsSpreadRuns() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        _ = try ExamFixtures.submittedEmail(.monthly, store: store, clock: clock)
        // Three disagreeing runs were saved before a crash; the job is picked up again.
        for (i, scores) in [[1, 3, 3, 3], [4, 3, 3, 3], [3, 3, 3, 3]].enumerated() {
            try store.saveRun(ExamFixtures.writingGrade(scores), entryId: 1, runIndex: i, model: "fake", at: clock.now)
        }
        let runner = FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        await queue.drain()
        #expect(await runner.calls == 2)
        #expect(ExamStore.decode(WritingGrade.self, try store.writingEntry(1)?.gradeJSON)?.runs.count == 5)
    }

    @Test func writeSheetEntryIsQueuedAndGraded() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let id = try store.saveWriting(surface: "write", promptId: "life-1", prompt: "Describe your week.",
                                       text: "Last week I managed to finish the dashboard, although it was hard.", at: clock.now)
        #expect(try store.writingEntry(id)?.gradeStatus == "pending")
        let runner = FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        let seen = ReportBox()
        await queue.observe { seen.add($0) }
        let report = await queue.drain()
        #expect(report.graded.count == 1)
        #expect(seen.reports.last?.graded.count == 1, "the observer hears about every graded job")
        #expect(try store.writingEntry(id)?.gradeStatus == "graded")
        #expect(!(await queue.isDraining))
    }

    @Test func claudeUnavailableKeepsJobQueued() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (session, jobs) = try ExamFixtures.submittedEmail(.weekly, store: store, clock: clock)
        let runner = FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])], errors: [.notInstalled])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        let report = await queue.drain()
        #expect(report.unavailable)
        let job = try #require(try store.job(jobs[0]))
        #expect(job.status == "queued")
        #expect(job.attempts == 0)
        #expect(try store.writingEntry(1)?.gradeStatus == "pending")
        // No overall band until the grade arrives; objective parts were already stored.
        #expect(!(try store.bands(attemptId: session.id).contains { $0.skill == BandHistoryRecord.overall }))
        // An hour later Claude is back and the job completes.
        clock.advance(by: 3601)
        #expect(await queue.drain().graded == jobs)
    }

    @Test func usageLimitPausesQueueForAnHour() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (_, jobs) = try ExamFixtures.submittedEmail(.weekly, store: store, clock: clock)
        let runner = FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])], errors: [.usageLimit("limit")])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        #expect(await queue.drain().unavailable)
        #expect(await queue.pausedUntil != nil)
        clock.advance(by: 1800)
        #expect(await queue.drain().unavailable) // still paused, no call made
        #expect(await runner.calls == 1)
        clock.advance(by: 1801)
        #expect(await queue.drain().graded == jobs)
        #expect(try store.job(jobs[0])?.attempts == 0)
    }

    @Test func failuresBackOffThenGiveUpAfterFour() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (session, jobs) = try ExamFixtures.submittedEmail(.weekly, store: store, clock: clock)
        let runner = FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])],
                                     errors: [.timedOut, .noStructuredOutput, .failed("x"), .failed("y")])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        let waits: [TimeInterval] = [60, 300, 1800]
        for (i, wait) in waits.enumerated() {
            #expect(await queue.drain().retried == jobs)
            let job = try #require(try store.job(jobs[0]))
            #expect(job.attempts == i + 1)
            #expect(job.nextAttemptAt == ExamStore.ms(clock.now) + Int64(wait * 1000))
            #expect(await queue.drain().retried.isEmpty) // not due yet
            clock.advance(by: wait)
        }
        #expect(await queue.drain().failed == jobs)
        #expect(try store.job(jobs[0])?.status == "failed")
        #expect(try store.writingEntry(1)?.gradeStatus == "failed")
        // The attempt still finalizes on its objective evidence.
        #expect(try store.bands(attemptId: session.id).contains { $0.skill == BandHistoryRecord.overall })
    }

    /// A morning offline (every attempt fails) must not fix the public band on the writing prior;
    /// the job is retried on the next launch and the public band is set once the grade arrives.
    @Test func transientClaudeFailureDoesNotFixPlacementPublicBand() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (session, jobs) = try ExamFixtures.submittedEmail(.placement, store: store, clock: clock)
        let offline = ClaudeCLIError.failed("API Error: Connection error.")
        let runner = FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])], errors: [offline, offline, offline, offline])
        let queue = try ClaudeJobQueue(store: store, runner: runner, clock: clock)
        for _ in 0..<4 {
            await queue.drain()
            clock.advance(by: 31 * 60)
        }
        #expect(try store.job(jobs[0])?.status == "failed")
        #expect(try store.publicBand() == nil)
        #expect(try store.bands(attemptId: session.id).contains { $0.skill == BandHistoryRecord.overall })
        // Next launch: the failed job is queued again with fresh attempts and grades.
        #expect(await queue.retryFailedJobs() == 1)
        #expect(try store.writingEntry(1)?.gradeStatus == "pending")
        #expect(await queue.drain().graded == jobs)
        #expect(try store.publicBand() != nil)
        let overall = try store.bands(attemptId: session.id).filter { $0.skill == BandHistoryRecord.overall }
        #expect(overall.count == 1)
    }

    /// A stale runner of a finished attempt (paused copy + resumed copy) can't save or void it again.
    @Test func closedAttemptIgnoresSecondSaveAndVoid() throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = ExamSession(blueprint: ExamFixtures.emailOnly(.placement), library: ExamFixtures.library,
                                  priors: ExamFixtures.priors(), seed: 3, clock: clock)
        try store.begin(session)
        session.answer(.text("Dear Ana, the plan depends on the budget. Best, Sam"))
        let submitted = session.submit()
        let outcome = try #require(submitted)
        #expect(try store.save(session, outcome: outcome).count == 1)
        let bands = try store.bands(attemptId: session.id).count
        #expect(try store.save(session, outcome: outcome).isEmpty)
        try store.void(session)
        #expect(try store.attempt(session.id)?.status == "done")
        #expect(try store.bands(attemptId: session.id).count == bands)
    }

    @Test func integrityVerdictVerifiesBands() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (session, _) = try ExamFixtures.submittedEmail(.weekly, store: store, clock: clock)
        let queue = try ClaudeJobQueue(store: store, runner: FakeGradeRunner(results: [ExamFixtures.writingGrade([3, 3, 3, 3])]),
                                       clock: clock)
        await queue.drain()
        #expect(try store.attempt(session.id)?.integrity == nil)
        #expect(try store.bands(attemptId: session.id).allSatisfy { !$0.verified })
        try store.setIntegrity(attemptId: session.id, .warning, confirmed: true)
        #expect(try store.bands(attemptId: session.id).allSatisfy(\.verified))
        try store.setIntegrity(attemptId: session.id, .violation)
        #expect(try store.attempt(session.id)?.integrity == "VIOLATION")
        #expect(try store.bands(attemptId: session.id).allSatisfy { !$0.verified })
        try store.logIntegrity(attemptId: session.id, kind: .paste, at: clock.now)
        let events = try await store.database.reader.read { try IntegrityEvent.fetchCount($0) }
        #expect(events == 1)
    }

    @Test func runningJobsAreRequeuedAtStartup() async throws {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        let (_, jobs) = try ExamFixtures.submittedEmail(.weekly, store: store, clock: clock)
        _ = try store.claimNextJob(now: clock.now)
        #expect(try store.job(jobs[0])?.status == "running")
        _ = try ClaudeJobQueue(store: store, runner: FakeGradeRunner(results: []), clock: clock)
        #expect(try store.job(jobs[0])?.status == "queued")
    }
}

/// Collects queue reports from the observer (called on the queue's executor).
final class ReportBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [ClaudeJobQueue.Report] = []
    func add(_ r: ClaudeJobQueue.Report) { lock.withLock { stored.append(r) } }
    var reports: [ClaudeJobQueue.Report] { lock.withLock { stored } }
}
