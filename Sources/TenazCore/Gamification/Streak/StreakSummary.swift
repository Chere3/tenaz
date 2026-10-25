/// The streak as of one learning day, recomputed from the set of qualified days.
public struct StreakSummary: Equatable, Sendable {
    public var current = 0
    public var best = 0
    public var freezes = 0
    /// Missed days bridged by a freeze (closed gaps only).
    public var frozenDays: Set<Int> = []
    /// Today already met the minimum viable day.
    public var qualifiedToday = false
    /// The headline: qualified days in the last 7 (today included).
    public var daysPracticedLast7 = 0
    /// Days missed right before today (0 when yesterday counted).
    public var missedBeforeToday = 0
    /// 3+ missed days: show "welcome back, 1-minute restart" and pause penalties today.
    public var welcomeBack: Bool { missedBeforeToday >= StreakEngine.welcomeBackAfterMissedDays }
    /// Weekly goal (5 of 7) met for the week ending today.
    public var weeklyGoalMet: Bool { daysPracticedLast7 >= StreakEngine.weeklyGoalDays }
}
