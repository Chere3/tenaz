import Foundation

/// Every intrusion setting. Stored in UserDefaults (never SQL, PLAN §4.3). Everything intrusive
/// ships OFF (DECISIONS rule 2); the enable toggles stay locked until calendar access is granted or
/// The learner ticks the "mic/camera/app detection only" acknowledgement (F14).
public struct IntrusionSettings: Codable, Equatable, Sendable {
    public enum Keys {
        public static let overlaysEnabled = "overlaysEnabled"
        public static let gateEnabled = "gateEnabled"
        public static let killSwitch = "killSwitch"
        /// Hotkey kill switch: intrusions stay off until this time (next 04:00), seconds since 1970.
        public static let killSwitchUntil = "killSwitchUntil"
        /// The popover's "Pause intrusions 1 h" (a Date or seconds since 1970).
        public static let pausedUntil = "intrusionsPausedUntil"
        /// "I'm in a meeting" / "Joining a call": nothing until this time.
        public static let meetingUntil = "intrusionsMeetingUntil"
        public static let detectionOnlyAck = "meetingDetectionOnlyAck"
        public static let overlayMode = "overlayMode"
        public static let overlaysPerDay = "overlaysPerDay"
        public static let overlayGapMinutes = "overlayGapMinutes"
        public static let quietStart = "quietHoursStart"
        public static let quietEnd = "quietHoursEnd"
        public static let triggerUnlock = "triggerUnlock"
        public static let triggerIdle = "triggerIdleReturn"
        public static let triggerAppSwitch = "triggerAppSwitch"
        public static let gateWords = "gateMinWords"
    }

    public static let maxOverlaysPerDay = 8
    public static let minOverlayGapMinutes = 40
    public static let gatesPerDay = 3
    public static let gateGapHours = 2.0
    public static let gateLockedMinutes = 30.0

    public var overlaysEnabled = false
    public var gateEnabled = false
    public var detectionOnlyAck = false
    public var overlayMode = OverlayMode.sticker
    /// 1...8 (never above the cap of 8).
    public var overlaysPerDay = IntrusionSettings.maxOverlaysPerDay
    /// ≥ 40 minutes between batches.
    public var overlayGapMinutes = IntrusionSettings.minOverlayGapMinutes
    public var quietHours = QuietHours.standard
    public var triggers = IntrusionTriggers()
    /// Gate floor: 25 by default (25-40 words, PLAN ruling 5).
    public var gateMinWords = GateRequirement.standard.minWords

    public init() {}

    public init(defaults d: UserDefaults) {
        overlaysEnabled = d.bool(forKey: Keys.overlaysEnabled)
        gateEnabled = d.bool(forKey: Keys.gateEnabled)
        detectionOnlyAck = d.bool(forKey: Keys.detectionOnlyAck)
        overlayMode = d.string(forKey: Keys.overlayMode).flatMap(OverlayMode.init(rawValue:)) ?? .sticker
        if let n = d.object(forKey: Keys.overlaysPerDay) as? Int { overlaysPerDay = n }
        if let n = d.object(forKey: Keys.overlayGapMinutes) as? Int { overlayGapMinutes = n }
        if let s = d.object(forKey: Keys.quietStart) as? Int { quietHours.startMinute = s }
        if let e = d.object(forKey: Keys.quietEnd) as? Int { quietHours.endMinute = e }
        triggers.unlock = d.object(forKey: Keys.triggerUnlock) as? Bool ?? true
        triggers.idleReturn = d.object(forKey: Keys.triggerIdle) as? Bool ?? true
        triggers.appSwitch = d.object(forKey: Keys.triggerAppSwitch) as? Bool ?? true
        if let w = d.object(forKey: Keys.gateWords) as? Int { gateMinWords = w }
        clamp()
    }

    public func save(to d: UserDefaults) {
        d.set(overlaysEnabled, forKey: Keys.overlaysEnabled)
        d.set(gateEnabled, forKey: Keys.gateEnabled)
        d.set(detectionOnlyAck, forKey: Keys.detectionOnlyAck)
        d.set(overlayMode.rawValue, forKey: Keys.overlayMode)
        d.set(overlaysPerDay, forKey: Keys.overlaysPerDay)
        d.set(overlayGapMinutes, forKey: Keys.overlayGapMinutes)
        d.set(quietHours.startMinute, forKey: Keys.quietStart)
        d.set(quietHours.endMinute, forKey: Keys.quietEnd)
        d.set(triggers.unlock, forKey: Keys.triggerUnlock)
        d.set(triggers.idleReturn, forKey: Keys.triggerIdle)
        d.set(triggers.appSwitch, forKey: Keys.triggerAppSwitch)
        d.set(gateMinWords, forKey: Keys.gateWords)
    }

    /// Keeps every number inside the safety caps whatever was written to defaults.
    public mutating func clamp() {
        overlaysPerDay = min(Self.maxOverlaysPerDay, max(1, overlaysPerDay))
        overlayGapMinutes = max(Self.minOverlayGapMinutes, min(240, overlayGapMinutes))
        gateMinWords = min(40, max(25, gateMinWords))
    }

    /// A Date written by the popover, or seconds since 1970.
    public static func date(_ d: UserDefaults, _ key: String) -> Date? {
        switch d.object(forKey: key) {
        case let date as Date: date
        case let n as Double: Date(timeIntervalSince1970: n)
        case let n as Int: Date(timeIntervalSince1970: Double(n))
        default: nil
        }
    }
}
