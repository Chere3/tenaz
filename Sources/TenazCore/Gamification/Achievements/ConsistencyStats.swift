import Foundation

/// Day-pattern statistics for streak-type achievements, computed from qualified days.
public enum ConsistencyStats {
    /// Longest run of consecutive days in `days`.
    public static func longestRun(_ days: Set<Int>) -> Int {
        var best = 0
        for d in days where !days.contains(LearningDays.adding(-1, to: d)) {
            var n = 1
            var next = LearningDays.adding(1, to: d)
            while days.contains(next) {
                n += 1
                next = LearningDays.adding(1, to: next)
            }
            best = max(best, n)
        }
        return best
    }

    /// Longest run of consecutive weekends with both Saturday and Sunday qualified.
    public static func longestWeekendRun(_ qualified: Set<Int>) -> Int {
        let saturdays = Set(qualified.filter { LearningDays.weekday($0) == 7 && qualified.contains(LearningDays.adding(1, to: $0)) })
        var best = 0
        for s in saturdays where !saturdays.contains(LearningDays.adding(-7, to: s)) {
            var n = 1
            var next = LearningDays.adding(7, to: s)
            while saturdays.contains(next) {
                n += 1
                next = LearningDays.adding(7, to: next)
            }
            best = max(best, n)
        }
        return best
    }

    /// Longest run of Monday-Sunday weeks with at least 5 qualified days (the current week
    /// counts once it already has 5).
    public static func longestWeeklyGoalRun(_ qualified: Set<Int>) -> Int {
        var perWeek: [Int: Int] = [:]
        for d in qualified { perWeek[LearningDays.weekStart(d), default: 0] += 1 }
        let goalWeeks = Set(perWeek.filter { $0.value >= StreakEngine.weeklyGoalDays }.keys)
        var best = 0
        for w in goalWeeks where !goalWeeks.contains(LearningDays.adding(-7, to: w)) {
            var n = 1
            var next = LearningDays.adding(7, to: w)
            while goalWeeks.contains(next) {
                n += 1
                next = LearningDays.adding(7, to: next)
            }
            best = max(best, n)
        }
        return best
    }

    /// Back after 5+ missed days, then 5 qualified days within the 7 days starting at the return.
    public static func phoenix(_ qualified: Set<Int>) -> Bool {
        let sorted = qualified.sorted()
        for (prev, next) in zip(sorted, sorted.dropFirst()) where LearningDays.distance(from: prev, to: next) - 1 >= 5 {
            let window = LearningDays.range(next, through: LearningDays.adding(6, to: next))
            if window.filter(qualified.contains).count >= StreakEngine.weeklyGoalDays { return true }
        }
        return false
    }
}
