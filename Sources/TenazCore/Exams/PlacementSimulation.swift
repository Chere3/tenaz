import Foundation

/// End-to-end placement check on a throwaway in-memory database: a `SimulatedLearner` takes the
/// placement, the attempt is stored, and the grading queue runs with a `SimulatedGradeRunner`, so
/// the result is the same overall band the app would record. Used by `--tenaz-selftest placement-sim`.
public enum PlacementSimulation {
    public struct Result: Sendable {
        public var seed: UInt64
        public var truthBand: Double
        /// Per skill after the objective parts (writing/speaking still at the prior: "grade pending").
        public var objective: [SkillOutcome]
        public var pendingBeforeGrading: [ExamSkill]
        /// Per skill after the queued grades ran.
        public var final: [ExamSkill: AbilityEstimator]
        public var overall: OverallBand
        /// The overall row the store wrote once grading finished (nil if a job is still open).
        public var recordedOverall: Double?
        public var taskCount: Int
        public var nominalMinutes: Double

        public var withinHalfBand: Bool { abs(overall.band - truthBand) <= 0.5 }
    }

    public static func run(theta: Double, seed: UInt64, blueprint: ExamBlueprint, library: ContentLibrary) async throws -> Result {
        let store = ExamStore(database: try TenazDatabase.inMemory())
        let clock = TestClock()
        var session = ExamSession(blueprint: blueprint, library: library, priors: try store.priors(for: .placement),
                                  seed: seed, clock: clock)
        try store.begin(session)
        var learner = SimulatedLearner(theta: theta, seed: seed &* 7919)
        while let task = session.currentTask {
            clock.advance(by: 20)
            session.answer(learner.answer(task))
            try store.recordResponse(session, taskId: task.id)
        }
        guard let outcome = session.submit() else { throw ClaudeCLIError.failed("placement did not submit") }
        try store.save(session, outcome: outcome)
        let queue = try ClaudeJobQueue(store: store, runner: SimulatedGradeRunner(theta: theta), clock: clock)
        await queue.drain()
        let final = try store.skillStates()
        let overallRow = try store.bands(attemptId: session.id).last { $0.skill == BandHistoryRecord.overall }
        return Result(seed: seed, truthBand: AbilityEstimator.band(for: theta), objective: outcome.skills,
                      pendingBeforeGrading: outcome.pendingSkills, final: final, overall: OverallBand(estimates: final), recordedOverall: overallRow?.band,
                      taskCount: session.tasks.count, nominalMinutes: blueprint.nominalMinutes)
    }
}
