/// Escape hatches used in the review week, by kind (PLAN F10 honest hatches, F16). Counted, never
/// blocked. Read from `hatch_event` (plus `day_stat` and the penalty log as floors).
public struct HatchCounts: Codable, Equatable, Sendable {
    public var killSwitch = 0
    public var pause = 0
    public var meetingClaims = 0
    public var uncorroboratedClaims = 0
    public var snoozes = 0
    public var skips = 0
    public var emergencySkips = 0

    public init() {}

    public var total: Int { killSwitch + pause + meetingClaims + uncorroboratedClaims + snoozes + skips + emergencySkips }

    /// Two or more kill-switch uses in a week ask "which rule was too much?" (never a penalty).
    public var asksRenegotiation: Bool { killSwitch >= 2 }
}
