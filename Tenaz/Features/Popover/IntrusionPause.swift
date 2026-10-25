import Foundation

/// "Pause intrusions 1 h" from the popover. Stored as a `Date` in UserDefaults under
/// `intrusionsPausedUntil`; the intrusion coordinator must treat any time before it as paused
/// (read it with `IntrusionPause.until` or `UserDefaults.standard.object(forKey:) as? Date`).
/// Always instant and never priced (PLAN F10 honest hatches).
enum IntrusionPause {
    static let key = "intrusionsPausedUntil"
    static let length: TimeInterval = 3600

    /// The end of the current pause, or nil when intrusions are not paused.
    static func until(now: Date = .now, defaults: UserDefaults = .standard) -> Date? {
        let stored = defaults.object(forKey: key)
        // The intrusion coordinator writes seconds since 1970; the popover writes a Date.
        let date = (stored as? Date) ?? (stored as? Double).map { Date(timeIntervalSince1970: $0) }
        guard let date, date > now else { return nil }
        return date
    }

    static func pause(now: Date = .now, defaults: UserDefaults = .standard) -> Date {
        let end = now.addingTimeInterval(length)
        defaults.set(end, forKey: key)
        return end
    }

    static func resume(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
