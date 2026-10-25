/// The decision pipeline's answer for one trigger.
public enum IntrusionVerdict: Equatable, Sendable {
    /// Show it, at most this big.
    case show(OverlayMode)
    /// Not now, for a passing reason (meeting, idle, caps); the next trigger may succeed.
    case deferred(String)
    /// Switched off: kill switch, disabled, paused, quiet hours.
    case deny(String)

    /// `intrusion_log.decision`.
    public var decision: String {
        switch self {
        case .show: "allow"
        case .deferred: "defer"
        case .deny: "deny"
        }
    }

    public var reason: String? {
        switch self {
        case .show: nil
        case let .deferred(r), let .deny(r): r
        }
    }
}
