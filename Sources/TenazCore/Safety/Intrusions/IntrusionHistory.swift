import Foundation

/// When each surface was shown recently, read from `intrusion_log` (outcomes that reached the screen).
public struct IntrusionHistory: Equatable, Sendable {
    public var shown: [Date]

    public init(shown: [Date] = []) { self.shown = shown.sorted() }

    public func count(onDayOf now: Date, calendar: Calendar = .current) -> Int {
        let day = DayBoundary.day(for: now, calendar: calendar)
        return shown.filter { DayBoundary.day(for: $0, calendar: calendar) == day }.count
    }

    public var last: Date? { shown.last }
}
