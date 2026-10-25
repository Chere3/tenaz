import Foundation

public extension DayBoundary {
    /// The moment (04:00 local) the learning day containing `date` started.
    static func start(ofDayContaining date: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.startOfDay(for: date.addingTimeInterval(-Double(hour) * 3600))
        return calendar.date(byAdding: .hour, value: hour, to: midnight) ?? midnight
    }
}
