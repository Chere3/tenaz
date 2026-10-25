/// One skill's result for an attempt. `pending` = a Claude grade for this skill hasn't arrived,
/// so the band shown is objective-only (or the prior) until it does.
public struct SkillOutcome: Equatable, Sendable {
    public var skill: ExamSkill
    public var estimate: AbilityEstimator
    /// Weighted units right / total in this attempt (rubric units count as right at ≥3 of 5).
    public var correct: Double
    public var total: Double
    public var pending: Bool

    public var band: Double { estimate.band }
    public var range: ClosedRange<Double> { estimate.bandRange }
}
