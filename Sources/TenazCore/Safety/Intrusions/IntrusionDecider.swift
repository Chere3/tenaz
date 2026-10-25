import Foundation

/// The one decision pipeline every intrusive surface goes through, in this order (PLAN F1, F2, F14):
/// kill switch → switched on (and allowed by F14) → pause / meeting / snooze → quiet hours →
/// trigger enabled → `InterruptionPolicy` on the live signals → caps (per day, minimum gap).
/// Nothing reaches the screen unless every step says yes.
public enum IntrusionDecider {
    public static func decide(_ r: IntrusionRequest, calendar: Calendar = .current) -> IntrusionVerdict {
        let now = r.now
        if let reason = r.killSwitch.reason(at: now) { return .deny(reason) }
        let enabled = r.surface == .overlay ? r.settings.overlaysEnabled : r.settings.gateEnabled
        if !enabled, r.trigger != .smoke { return .deny("\(r.surface.rawValue) is off") }
        if r.trigger != .smoke,
           !IntrusionEnableRule.canEnable(calendarGranted: r.calendarGranted, acknowledged: r.settings.detectionOnlyAck) {
            return .deny("needs Calendar access or the detection-only acknowledgement")
        }
        if let until = r.pausedUntil, now < until { return .deny("paused") }
        if let until = r.meetingUntil, now < until { return .deny("in a meeting") }
        if let until = r.snoozedUntil, now < until { return .deny("snoozed") }
        if r.settings.quietHours.contains(now, calendar: calendar) { return .deny("quiet hours") }
        if r.surface == .overlay, !r.settings.triggers.allows(r.trigger) { return .deny("trigger \(r.trigger.rawValue) is off") }

        if case let .deferred(reason) = r.policy.decide(r.signals, now: now) { return .deferred(reason) }

        switch r.surface {
        case .overlay:
            if r.history.count(onDayOf: now, calendar: calendar) >= r.settings.overlaysPerDay { return .deferred("daily cap reached") }
            if let last = r.history.last, now.timeIntervalSince(last) < Double(r.settings.overlayGapMinutes) * 60 {
                return .deferred("too soon after the last batch")
            }
            return .show(r.callOrChatFrontmost ? .sticker : r.settings.overlayMode)
        case .gate:
            if r.callOrChatFrontmost { return .deferred("call or chat app in front") }
            if r.history.count(onDayOf: now, calendar: calendar) >= IntrusionSettings.gatesPerDay { return .deferred("3 gates today") }
            if let last = r.history.last, now.timeIntervalSince(last) < IntrusionSettings.gateGapHours * 3600 {
                return .deferred("less than 2 h since the last gate")
            }
            return .show(.poster)
        }
    }

    /// Is a surface that is already on screen still allowed? Any kill switch or deferring signal
    /// closes it within a second (F14 "while a surface is visible"), for free.
    public static func mustCloseVisible(killSwitch: KillSwitchState, signals: InterruptionSignals, policy: InterruptionPolicy,
                                        now: Date) -> String? {
        if let reason = killSwitch.reason(at: now) { return reason }
        // While the learner answers, idle time is not a meeting signal: ignore it here.
        var live = signals
        live.idleSeconds = 0
        if case let .deferred(reason) = policy.decide(live, now: now) { return reason }
        return nil
    }
}
