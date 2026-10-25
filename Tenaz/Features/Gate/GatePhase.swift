/// Where the gate is.
enum GatePhase: Equatable {
    case writing
    /// Esc pressed once: "press Esc again to skip".
    case skipArmed
    /// The plain confirmation with the cost.
    case confirmingSkip
    /// Accepted: the UNLOCKED stamp, then the gate closes.
    case unlocked
    /// 5 minutes are up: "We'll finish later", then it closes.
    case later
}
