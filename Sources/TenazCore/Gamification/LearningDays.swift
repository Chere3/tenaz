import Foundation

/// Arithmetic on `yyyymmdd` learning-day numbers. Never subtract the integers directly
/// (20261101 - 20261031 is not 1); go through this calendar instead.
public enum LearningDays {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    static func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100, hour: 12))!
    }

    static func number(_ date: Date) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return c.year! * 10000 + c.month! * 100 + c.day!
    }

    public static func adding(_ days: Int, to day: Int) -> Int {
        number(calendar.date(byAdding: .day, value: days, to: date(day))!)
    }

    /// Whole days from `a` to `b` (positive when `b` is later).
    public static func distance(from a: Int, to b: Int) -> Int {
        calendar.dateComponents([.day], from: date(a), to: date(b)).day!
    }

    /// 1 = Sunday ... 7 = Saturday.
    public static func weekday(_ day: Int) -> Int { calendar.component(.weekday, from: date(day)) }

    /// The Monday of the week containing `day`.
    public static func weekStart(_ day: Int) -> Int {
        let offset = (weekday(day) + 5) % 7 // Monday 0 ... Sunday 6
        return adding(-offset, to: day)
    }

    /// `yyyymm`, used for the monthly Mercy-token allowance.
    public static func month(_ day: Int) -> Int { day / 100 }

    /// Every day from `a` through `b`, inclusive; empty when `b < a`.
    public static func range(_ a: Int, through b: Int) -> [Int] {
        var out: [Int] = []
        var d = a
        while d <= b {
            out.append(d)
            d = adding(1, to: d)
        }
        return out
    }
}
