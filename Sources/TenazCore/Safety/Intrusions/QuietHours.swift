import Foundation

/// A nightly window when nothing intrusive appears (default 22:30-08:00). Minutes after midnight;
/// a window whose start is after its end wraps past midnight.
public struct QuietHours: Codable, Equatable, Sendable {
    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int = 22 * 60 + 30, endMinute: Int = 8 * 60) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public static let standard = QuietHours()

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if startMinute == endMinute { return false }
        return startMinute < endMinute ? (m >= startMinute && m < endMinute) : (m >= startMinute || m < endMinute)
    }

    /// "22:30".
    public static func label(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
