/// Everything that can move XP, meters, streak, quests or achievements. UI areas send these to
/// `GamificationEngine.handle(_:)` and render the returned `GamificationEffects`.
public enum GamificationEvent: Equatable, Sendable {
    case reviewAnswered(AnsweredReview)
    case productionDone(Production)
    /// The unlock gate's paragraph was accepted (also counts as a production).
    case gateCompleted(Production)
    /// Emergency skip. Never refused; priced under the Contract and the daily caps.
    case gateSkipped(useMercy: Bool)
    /// The gate hit its 5-minute limit. `abandoned` = typed into it, then used another app over it
    /// (-10 under Response cost); otherwise it is `timeoutIdle` and free.
    case gateTimedOut(abandoned: Bool)
    case overlaySkipped
    /// "I'm in a meeting" / "Joining a call" with no meeting signal. The first 2 a day are free; after
    /// that -3 under Response cost, but only when a work calendar is configured and visible (F14).
    case meetingClaimUncorroborated(workCalendarVisible: Bool)
    /// Gives back a penalty: a meeting signal corroborated the claim later, or a meeting started while
    /// the surface was visible (`deferredMidway`). Pass `AppliedPenalty.eventId`.
    case penaltyRefunded(eventId: Int64)
    /// The kill switch or "Pause 1 h" was used: penalty-free, but today then qualifies for the
    /// streak only through the in-app minimum, and no freeze can cover it.
    case intrusionsPaused
    case examFinished(ExamCredit)
}
