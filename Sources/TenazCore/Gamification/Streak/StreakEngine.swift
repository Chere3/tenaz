/// Streak rules (PLAN F9, section 2 rows 2-3), ported from fluo's StreakEngine and replayed from
/// history so there is no hidden state to drift:
/// - a qualified day = 10 correct retrievals + 1 production (`qualifies`), day boundary 04:00;
/// - a freeze is earned every 7 qualified days, at most 2 are held;
/// - a gap of missed days is bridged only if enough freezes are banked for the whole gap,
///   otherwise the streak resets and the freezes are kept (never wasted on a lost cause);
/// - frozen days keep the streak alive but do not add to it; the best streak is kept forever;
/// - today is "in progress" until it ends, so it never breaks the streak by itself;
/// - a missed day on which the kill switch or "Pause 1 h" was used (`unfreezableDays`) can never be
///   covered by a freeze (PLAN F9 honest hatches).
public enum StreakEngine {
    public static let minCorrectRetrievals = 10
    public static let minProductions = 1
    public static let maxFreezes = 2
    public static let qualifiedDaysPerFreeze = 7
    public static let welcomeBackAfterMissedDays = 3
    public static let weeklyGoalDays = 5

    public static func qualifies(correctRetrievals: Int, productions: Int) -> Bool {
        correctRetrievals >= minCorrectRetrievals && productions >= minProductions
    }

    public static func summary(qualifiedDays: Set<Int>, today: Int, unfreezableDays: Set<Int> = []) -> StreakSummary {
        var s = StreakSummary()
        let past = qualifiedDays.filter { $0 <= today }
        s.qualifiedToday = past.contains(today)
        s.daysPracticedLast7 = LearningDays.range(LearningDays.adding(-6, to: today), through: today)
            .filter(past.contains).count
        guard let first = past.min() else { return s }

        var earned = 0
        var gap: [Int] = []
        func closeGap() {
            guard !gap.isEmpty else { return }
            if s.freezes >= gap.count, unfreezableDays.isDisjoint(with: gap) {
                s.freezes -= gap.count
                s.frozenDays.formUnion(gap)
            } else {
                s.current = 0
            }
            gap = []
        }
        for day in LearningDays.range(first, through: today) {
            if past.contains(day) {
                closeGap()
                s.current += 1
                s.best = max(s.best, s.current)
                earned += 1
                if earned % qualifiedDaysPerFreeze == 0 { s.freezes = min(maxFreezes, s.freezes + 1) }
            } else if day < today {
                gap.append(day)
            }
        }
        // An open gap (still missing as of yesterday) breaks the displayed streak only if the
        // banked freezes cannot cover it; nothing is consumed until the gap closes.
        s.missedBeforeToday = gap.count
        if !gap.isEmpty, gap.count > s.freezes || !unfreezableDays.isDisjoint(with: gap) { s.current = 0 }
        if s.qualifiedToday {
            // The gap closed today: count the missed days that preceded it.
            var d = LearningDays.adding(-1, to: today)
            var missed = 0
            while d >= first, !past.contains(d) {
                missed += 1
                d = LearningDays.adding(-1, to: d)
            }
            s.missedBeforeToday = missed
        }
        return s
    }
}
