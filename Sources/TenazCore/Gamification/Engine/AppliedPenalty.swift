/// A penalty the engine just applied or waived, with the rule that fired.
public struct AppliedPenalty: Equatable, Sendable {
    /// The `penalty_event` row, for `.penaltyRefunded(eventId:)`.
    public var eventId: Int64?
    public var cost: PenaltyCost
    public var vitality: Int
    public var scales: Int
    public var mercyUsed: Bool
    public var outcome: PenaltyOutcome
    /// When the learner chose the rule ("You chose this on <date>").
    public var ruleChosenAt: Int64?
}
