/// The Contract's rules (PLAN F10). Every rule ships off; the learner turns them on in a calm moment.
public enum PenaltyRuleKind: String, Codable, CaseIterable, Sendable {
    /// Vitality/Scales costs from the cost table (skips, abandoned gate, missed minimum,
    /// uncorroborated meeting claims). While it is off, a missed day only changes Tena's mood.
    case responseCost
    /// At Sick (Vitality ≤ 30): 15 no-hint reviews + a 60-word paragraph; each part regrows a limb.
    case repairTask
    /// A word failed twice becomes the gate's required chunk (enforced by the gate/overlay area).
    case forgottenWordReturns
    /// The gate's skip button appears after a 10 s countdown (enforced by the gate area).
    case strictGate
    /// +5 review cards after a missed day, inside the daily review cap.
    case extraCards
    /// A failed or VIOLATION mock schedules a retake in 48 h and costs 15 Vitality.
    case examStake
    /// After a chosen deadline, the sticker overlay over a frontmost fun app until today's minimum
    /// is done (enforced by the overlay area; never during a meeting, inside the daily caps).
    case funAppSpeedBump
    /// Needs Tivra patch P1; can never be enabled in v1.
    case tivraFunAppBlock

    public var canBeEnabled: Bool { self != .tivraFunAppBlock }
}
