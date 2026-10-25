import Foundation

extension PopoverState {
    /// The popover's view of today's summary.
    init(_ summary: TodaySummary, pausedUntil: Date? = IntrusionPause.until(), now: Date = .now) {
        self.init(mood: summary.mood, stage: summary.stage, levelLabel: summary.levelLabel, streakDays: summary.streakDays,
                  vitality: Double(summary.vitality), spirit: Double(summary.spirit), dueCount: summary.todaySetCount,
                  line: summary.line, primaryTitle: Self.pillTitle(summary.primary), primary: summary.primary,
                  streakAtRisk: Self.atRisk(summary, now: now), pausedUntil: pausedUntil, dueWord: summary.dueWord)
    }

    /// The pill names the action only; the hero already carries the count.
    private static func pillTitle(_ primary: HomePrimary) -> String {
        if case .review = primary { return "Review" }
        return primary.shortTitle
    }

    private static func atRisk(_ summary: TodaySummary, now: Date) -> Bool {
        Calendar.current.component(.hour, from: now) >= 20 && !summary.qualifiedToday && summary.streakDays > 0
    }
}
