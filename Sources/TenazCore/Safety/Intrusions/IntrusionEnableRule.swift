/// F14: overlays and the gate cannot be turned on until Calendar access is granted (so meetings are
/// visible) or the learner ticks "I understand: mic/camera/app detection only".
public enum IntrusionEnableRule {
    public static func canEnable(calendarGranted: Bool, acknowledged: Bool) -> Bool {
        calendarGranted || acknowledged
    }

    /// Plain-English reason shown next to a locked toggle, or nil when it can be turned on.
    public static func lockReason(calendarGranted: Bool, acknowledged: Bool) -> String? {
        canEnable(calendarGranted: calendarGranted, acknowledged: acknowledged) ? nil
            : "Give Tenaz Calendar access, or tick “I understand” below, before you turn this on."
    }
}
