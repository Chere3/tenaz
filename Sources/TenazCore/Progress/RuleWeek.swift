/// How one contract rule did this week: the experiment log (PLAN F10), not a judgement.
public struct RuleWeek: Equatable, Identifiable, Sendable {
    public var rule: String
    public var stats: PenaltyExperimentLog.Stats
    /// Escape rate over 60% two weeks running.
    public var suggestTurnOff: Bool

    public var id: String { rule }
    public var title: String { Self.names[rule] ?? rule }

    static let names: [String: String] = [
        PenaltyRuleKind.responseCost.rawValue: "Response cost",
        PenaltyRuleKind.repairTask.rawValue: "Repair task",
        PenaltyRuleKind.forgottenWordReturns.rawValue: "Forgotten word returns",
        PenaltyRuleKind.strictGate.rawValue: "Strict gate",
        PenaltyRuleKind.extraCards.rawValue: "Extra cards",
        PenaltyRuleKind.examStake.rawValue: "Exam stake",
        PenaltyRuleKind.funAppSpeedBump.rawValue: "Fun-app speed bump",
        PenaltyRuleKind.tivraFunAppBlock.rawValue: "Tivra fun-app block",
    ]
}
