import Foundation

/// Which unlocks may open the gate (F2): the Mac was locked or asleep for 30+ minutes, or this is the
/// first unlock of the learning day. Caps (3 a day, 2 h apart) are applied by `IntrusionDecider`.
public enum GateEligibility {
    public static func qualifies(lockedSince: Date?, now: Date, lastUnlock: Date?, calendar: Calendar = .current) -> Bool {
        let firstToday = lastUnlock.map { DayBoundary.day(for: $0, calendar: calendar) != DayBoundary.day(for: now, calendar: calendar) } ?? true
        if firstToday { return true }
        guard let since = lockedSince else { return false }
        return now.timeIntervalSince(since) >= IntrusionSettings.gateLockedMinutes * 60
    }
}
