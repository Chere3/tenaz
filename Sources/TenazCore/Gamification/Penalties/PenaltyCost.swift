/// The cost table (PLAN F10). Everything here needs its rule in force; level, mastered words and
/// access to the Mac are never touched.
public enum PenaltyCost: String, Codable, CaseIterable, Sendable {
    case overlaySkip, gateSkip
    /// `timeoutAbandoned`: typed into the gate, then used another app over it. `timeoutIdle` is free.
    case gateTimeoutAbandoned
    case missedMinimum
    /// "I'm in a meeting" beyond the 2 free uncorroborated claims a day, with a visible work calendar.
    case meetingClaimUncorroborated
    case examStake

    /// Vitality cost (negative). `gateSkip` is -10 instead when a Mercy token is spent.
    public var vitality: Int {
        switch self {
        case .overlaySkip: -3
        case .gateSkip: -20
        case .gateTimeoutAbandoned: -10
        case .missedMinimum: -10
        case .meetingClaimUncorroborated: -3
        case .examStake: -15
        }
    }

    public static let gateSkipWithMercy = -10

    public var scales: Int { self == .missedMinimum ? -ScalesRules.missedDayCost : 0 }

    /// The rule that must be in force for this cost to apply.
    public var rule: PenaltyRuleKind { self == .examStake ? .examStake : .responseCost }
}
