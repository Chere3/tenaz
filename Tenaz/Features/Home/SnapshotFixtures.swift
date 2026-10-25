import Foundation

/// Fixed moments so snapshots do not change with the clock.
enum SnapshotFixtures {
    /// Friday 23 Oct 2026, 08:30 local time.
    static let morning: Date = {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute) = (2026, 10, 23, 8, 30)
        return Calendar.current.date(from: c) ?? .now
    }()
}
