/// How an intrusion ended, or why it never showed (`intrusion_log.outcome`, PLAN §4.3).
public enum IntrusionOutcome: String, Codable, CaseIterable, Sendable {
    case shown
    /// Not shown: the kill switch, a pause, quiet hours, caps or a meeting signal said no.
    case deferred
    /// A meeting signal appeared while it was on screen: closed for free.
    case deferredMidway
    /// "Joining a call" on the gate: closed for free, gates wait 60 min.
    case deferredMeeting
    case snoozed
    case skipped
    case completed
    /// The watchdog closed it.
    case timeout
    /// Gate: nobody typed and the Mac stayed idle (free).
    case timeoutIdle
    /// Gate: the learner typed, then used another app over it.
    case timeoutAbandoned
    /// A kill switch closed it.
    case killed
    case meetingClaimUncorroborated
    /// Keys pressed right as it appeared: discarded, never graded.
    case earlyInput
}
