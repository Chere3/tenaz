import Foundation

/// Everything the decision pipeline needs for one trigger. The app fills it from UserDefaults,
/// the kill switches, `SignalProbes.read()` and `intrusion_log`; tests fill it by hand.
public struct IntrusionRequest: Sendable {
    public var surface: IntrusionSurface
    public var trigger: IntrusionTrigger
    public var now: Date
    public var settings: IntrusionSettings
    public var killSwitch: KillSwitchState
    public var calendarGranted: Bool
    /// Popover "Pause intrusions 1 h".
    public var pausedUntil: Date?
    /// "I'm in a meeting" / "Joining a call" (60 min).
    public var meetingUntil: Date?
    /// Snooze 5 min / "Not now" 15 min.
    public var snoozedUntil: Date?
    public var signals: InterruptionSignals
    public var policy: InterruptionPolicy
    /// A call or chat app is frontmost with no hard signal: sticker only, no gate.
    public var callOrChatFrontmost: Bool
    public var history: IntrusionHistory

    public init(surface: IntrusionSurface, trigger: IntrusionTrigger, now: Date, settings: IntrusionSettings,
                killSwitch: KillSwitchState = KillSwitchState(), calendarGranted: Bool = false, pausedUntil: Date? = nil,
                meetingUntil: Date? = nil, snoozedUntil: Date? = nil, signals: InterruptionSignals = InterruptionSignals(),
                policy: InterruptionPolicy = InterruptionPolicy(), callOrChatFrontmost: Bool = false,
                history: IntrusionHistory = IntrusionHistory()) {
        self.surface = surface
        self.trigger = trigger
        self.now = now
        self.settings = settings
        self.killSwitch = killSwitch
        self.calendarGranted = calendarGranted
        self.pausedUntil = pausedUntil
        self.meetingUntil = meetingUntil
        self.snoozedUntil = snoozedUntil
        self.signals = signals
        self.policy = policy
        self.callOrChatFrontmost = callOrChatFrontmost
        self.history = history
    }
}
