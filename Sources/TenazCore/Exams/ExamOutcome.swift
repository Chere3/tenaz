/// What `ExamSession.submit()` produces: objective scores now, Claude grades later.
public struct ExamOutcome: Sendable {
    public var attemptId: String
    public var kind: ExamKind
    /// Skills this attempt touched, in `ExamSkill.allCases` order.
    public var skills: [SkillOutcome]
    /// Posteriors for all five skills after the objective evidence.
    public var estimates: [ExamSkill: AbilityEstimator]
    /// Provisional while any grade is pending (pending skills still show their prior).
    public var overall: OverallBand
    public var pending: [PendingGrade]
    public var taskScores: [TaskScore]

    public var overallIsProvisional: Bool { !pending.isEmpty }
    /// For the result screen: "writing grade pending".
    public var pendingSkills: [ExamSkill] { ExamSkill.allCases.filter { s in pending.contains { $0.skill == s } } }
}
