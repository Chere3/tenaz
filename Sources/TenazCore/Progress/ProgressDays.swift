import Foundation

/// Converts `yyyymmdd` learning days to the moment they start (04:00 local).
enum ProgressDays {
    static func startMs(of day: Int, calendar: Calendar) -> Int64 {
        let noon = calendar.date(from: DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100, hour: 12))!
        return DayBoundary.start(ofDayContaining: noon, calendar: calendar).unixMilliseconds
    }

    /// The first moment after the learning day `day`.
    static func endMs(of day: Int, calendar: Calendar) -> Int64 {
        startMs(of: LearningDays.adding(1, to: day), calendar: calendar)
    }
}
