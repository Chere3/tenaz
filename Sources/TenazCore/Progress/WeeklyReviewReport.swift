/// Everything the 5-minute Sunday review shows (PLAN F16), computed from local data only.
public struct WeeklyReviewReport: Equatable, Sendable {
    public struct Day: Equatable, Identifiable, Sendable {
        public var day: Int
        public var qualified: Bool
        public var id: Int { day }
    }

    public var today: Int
    /// The Monday of the week being reviewed (the `weekly_review` key).
    public var weekStart: Int
    /// The last 7 learning days, oldest first, today last.
    public var last7: [Day]
    public var daysPracticed7: Int
    public var daysPracticed30: Int
    /// Mastered notes at the end of each of the last 30 days, oldest first.
    public var masteredSeries: [Int]
    public var masteredGained7: Int
    public var errors: [ErrorTrend]
    /// Rules that fired, were dismissed or escaped this week.
    public var rules: [RuleWeek]
    public var hatches: HatchCounts
    /// The 1-7 automaticity question is due (none in the last 2 weeks).
    public var automaticityDue: Bool
    public var lastAutomaticity: Int?
    public var plans: [IfThenPlanRecord]
    /// Already saved this week (the screen then shows "Saved").
    public var saved: WeeklyReviewRecord?

    public var masteredNow: Int { masteredSeries.last ?? 0 }
}
