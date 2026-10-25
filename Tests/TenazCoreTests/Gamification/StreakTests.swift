import Testing
@testable import TenazCore

/// Ported from fluo's StreakEngineTest, adapted to Tenaz (qualified day = 10 correct + 1 production,
/// freezes earned every 7 qualified days, hold max 2).
struct StreakTests {
    let base = 20261102
    func day(_ n: Int) -> Int { LearningDays.adding(n, to: base) }
    func days(_ ns: [Int]) -> Set<Int> { Set(ns.map(day)) }
    func run(_ range: Range<Int>) -> [Int] { Array(range) }

    @Test func minimumViableDayGatesQualification() {
        #expect(!StreakEngine.qualifies(correctRetrievals: 9, productions: 1))
        #expect(!StreakEngine.qualifies(correctRetrievals: 30, productions: 0))
        #expect(StreakEngine.qualifies(correctRetrievals: 10, productions: 1))
    }

    @Test func consecutiveDaysIncrement() {
        let s = StreakEngine.summary(qualifiedDays: days([0, 1, 2]), today: day(2))
        #expect(s.current == 3)
        #expect(s.best == 3)
    }

    @Test func inProgressDayIsNotBroken() {
        let s = StreakEngine.summary(qualifiedDays: days([0]), today: day(1))
        #expect(s.current == 1)
        #expect(!s.qualifiedToday)
    }

    @Test func gapWithoutFreezeResets() {
        let s = StreakEngine.summary(qualifiedDays: days([0, 1, 3]), today: day(3))
        #expect(s.current == 1)
        #expect(s.best == 2)
    }

    @Test func freezeBridging() {
        // 7 qualified days earn one freeze, which bridges one missed day.
        let s = StreakEngine.summary(qualifiedDays: days(run(0..<7) + [8]), today: day(8))
        #expect(s.current == 8)
        #expect(s.freezes == 0)
        #expect(s.frozenDays == [day(7)])
    }

    @Test func freezesBridgeOnlyWhenEnoughAreBanked() {
        // One freeze, two missed days: reset, and the freeze is kept.
        let s = StreakEngine.summary(qualifiedDays: days(run(0..<7) + [9]), today: day(9))
        #expect(s.current == 1)
        #expect(s.freezes == 1)
    }

    @Test func freezesAreCappedAtTwo() {
        let s = StreakEngine.summary(qualifiedDays: days(run(0..<28)), today: day(27))
        #expect(s.freezes == StreakEngine.maxFreezes)
    }

    @Test func openGapCoveredByFreezesIsNotBroken() {
        // Two freezes banked, two days missed so far: still alive until the gap outgrows them.
        let q = days(run(0..<14))
        #expect(StreakEngine.summary(qualifiedDays: q, today: day(16)).current == 14)
        #expect(StreakEngine.summary(qualifiedDays: q, today: day(17)).current == 0)
    }

    @Test func bestStreakKeptAcrossResets() {
        let s = StreakEngine.summary(qualifiedDays: days(run(0..<5) + [10]), today: day(10))
        #expect(s.current == 1)
        #expect(s.best == 5)
    }

    @Test func pausedDayCannotBeFrozen() {
        // A freeze is banked, but the missed day used the kill switch: the streak breaks.
        let q = days(run(0..<7) + [8])
        let s = StreakEngine.summary(qualifiedDays: q, today: day(8), unfreezableDays: [day(7)])
        #expect(s.current == 1)
    }

    @Test func daysPracticedLast7IsTheHeadline() {
        let s = StreakEngine.summary(qualifiedDays: days([0, 1, 3, 4, 6]), today: day(6))
        #expect(s.daysPracticedLast7 == 5)
        #expect(s.weeklyGoalMet)
    }

    @Test func welcomeBackAfterThreeMissedDays() {
        #expect(!StreakEngine.summary(qualifiedDays: days([0]), today: day(3)).welcomeBack)
        #expect(StreakEngine.summary(qualifiedDays: days([0]), today: day(4)).welcomeBack)
        // Still a welcome-back day after qualifying on it.
        #expect(StreakEngine.summary(qualifiedDays: days([0, 4]), today: day(4)).welcomeBack)
        #expect(!StreakEngine.summary(qualifiedDays: days([0, 4]), today: day(5)).welcomeBack)
    }

    @Test func engineUsesTheFourAMBoundary() throws {
        // 02:00 belongs to the previous learning day.
        let f = try GamificationFixture(hour: 2)
        #expect(f.today == 20261101)
        f.advance(hours: 2)
        #expect(f.today == 20261102)
    }

    @Test func engineStreakAcrossDaysAndKillSwitch() throws {
        let f = try GamificationFixture()
        for _ in 0..<3 {
            try f.qualifyToday()
            f.advance(days: 1)
        }
        #expect(try f.state.streak.current == 3)
        // Pausing intrusions on a qualified day changes nothing.
        try f.engine.handle(.intrusionsPaused)
        try f.qualifyToday()
        f.advance(days: 1)
        #expect(try f.state.streak.current == 4)
    }
}
