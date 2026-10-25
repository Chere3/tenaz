/// What asked for an intrusion (`intrusion_log.trigger`). Triggers fire only at boundaries.
public enum IntrusionTrigger: String, Codable, CaseIterable, Sendable {
    /// Screen unlocked or the Mac woke (merged and debounced).
    case unlock
    /// Back at the Mac after 5+ minutes idle.
    case idleReturn
    /// Switched apps after 25+ minutes in one app.
    case appSwitch
    /// Started by hand (Settings "Try it now").
    case manual
    /// `--tenaz-smoke` automation.
    case smoke
}
