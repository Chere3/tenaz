import Foundation

/// What the Mac looks like right now, gathered by the app's probes.
/// Any probe that fails reports `nil`, which counts as "maybe busy" (fail-safe: don't interrupt).
public struct InterruptionSignals: Equatable, Sendable {
    public var microphoneInUse: Bool?
    public var cameraInUse: Bool?
    public var meetingAppFrontmost: Bool?
    public var calendarEventNow: Bool?
    public var displaySleepPreventedByOtherApp: Bool?
    public var focusModeOn: Bool?
    public var idleSeconds: Double?
    public var tenazUsesMicrophone = false

    public init(
        microphoneInUse: Bool? = false, cameraInUse: Bool? = false, meetingAppFrontmost: Bool? = false,
        calendarEventNow: Bool? = false, displaySleepPreventedByOtherApp: Bool? = false, focusModeOn: Bool? = false,
        idleSeconds: Double? = 0, tenazUsesMicrophone: Bool = false
    ) {
        self.microphoneInUse = microphoneInUse
        self.cameraInUse = cameraInUse
        self.meetingAppFrontmost = meetingAppFrontmost
        self.calendarEventNow = calendarEventNow
        self.displaySleepPreventedByOtherApp = displaySleepPreventedByOtherApp
        self.focusModeOn = focusModeOn
        self.idleSeconds = idleSeconds
        self.tenazUsesMicrophone = tenazUsesMicrophone
    }
}

public enum InterruptionDecision: Equatable, Sendable {
    case allow
    case deferred(reason: String)
}

public struct InterruptionPolicy: Codable, Equatable, Sendable {
    /// Respect macOS Focus modes (default on). The learner can turn this off for a self-set "Study" focus.
    public var respectFocus = true
    /// Don't show anything if the learner has been away longer than this.
    public var maxIdleSeconds: Double = 120
    /// "I'm in a meeting" button: nothing shows until this time.
    public var snoozedUntil: Date?

    public init() {}

    public func decide(_ s: InterruptionSignals, now: Date = Date()) -> InterruptionDecision {
        if let until = snoozedUntil, now < until { return .deferred(reason: "paused until \(until.formatted(date: .omitted, time: .shortened))") }
        // A missing reading (nil) is treated as "busy".
        if s.cameraInUse != false { return .deferred(reason: "camera in use") }
        if s.microphoneInUse != false && !s.tenazUsesMicrophone { return .deferred(reason: "microphone in use") }
        if s.meetingAppFrontmost != false { return .deferred(reason: "meeting app in front") }
        if s.calendarEventNow != false { return .deferred(reason: "calendar event now") }
        if s.displaySleepPreventedByOtherApp != false { return .deferred(reason: "presentation or video playing") }
        if respectFocus && s.focusModeOn == true { return .deferred(reason: "Focus mode on") }
        guard let idle = s.idleSeconds else { return .deferred(reason: "can't read idle time") }
        if idle > maxIdleSeconds { return .deferred(reason: "you're away") }
        return .allow
    }
}

/// Caps how often each overlay can appear, so waking the laptop 15 times doesn't mean 15 gates.
public struct OverlaySchedule: Codable, Equatable, Sendable {
    public var minimumGap: TimeInterval
    public var maxPerDay: Int
    public private(set) var shown: [Date] = []

    public init(minimumGap: TimeInterval, maxPerDay: Int) {
        self.minimumGap = minimumGap
        self.maxPerDay = maxPerDay
    }

    public func canShow(at now: Date, calendar: Calendar = .current) -> Bool {
        if let last = shown.last, now.timeIntervalSince(last) < minimumGap { return false }
        return shown.filter { calendar.isDate($0, inSameDayAs: now) }.count < maxPerDay
    }

    public mutating func record(_ date: Date) {
        shown.append(date)
        if shown.count > 200 { shown.removeFirst(shown.count - 200) }
    }
}

/// The escape ladder every overlay must offer (docs/research/05-macos-mechanics.md §11).
public enum EscapeAction: String, Codable, Sendable {
    /// Free, limited per day.
    case snooze
    /// After a short countdown; costs a small penalty.
    case skip
    /// "I'm in a meeting": pauses everything for an hour, no penalty.
    case meeting
    /// Global hotkey / defaults / DISABLE file / watchdog: always works, turns overlays off.
    case killSwitch
    /// The overlay hit its maximum time on screen.
    case timeout
}
