import Testing
@testable import TenazCore

struct XPTests {
    @Test func curveValues() {
        #expect(LevelCurve.xpToNext(1) == 100)
        #expect(LevelCurve.xpToNext(5) == 441)
        #expect(LevelCurve.xpToNext(10) == 1065)
        #expect(LevelCurve.xpToNext(20) == 2712)
        #expect(LevelCurve.progress(totalXP: 0).level == 1)
        #expect(LevelCurve.progress(totalXP: 99).level == 1)
        #expect(LevelCurve.progress(totalXP: 100).level == 2)
        // About 57,900 XP to level 30 (PLAN F9).
        let to30 = (1..<30).map(LevelCurve.xpToNext).reduce(0, +)
        #expect((57_000...59_000).contains(to30))
    }

    @Test func reviewXPScalesWithDifficulty() {
        #expect(XPRules.review(difficulty: 1) == 10)
        #expect(XPRules.review(difficulty: 10) == 16)
        #expect(XPRules.review(difficulty: 5.5) == 13)
        #expect(XPRules.review(difficulty: 40) == 16) // clamped
    }

    @Test func productionAndExamRanges() {
        #expect(XPRules.production(quality: 0) == 0)
        #expect(XPRules.production(quality: 0.2) == 20)
        #expect(XPRules.production(quality: 1) == 40)
        #expect(XPRules.examSection(band: 1) == 100)
        #expect(XPRules.examSection(band: 6) == 300)
        #expect(XPRules.quest(10) == 50)
        #expect(XPRules.quest(500) == 150)
    }

    @Test func antiFarmingHalvesAfterTwoRepeats() {
        #expect(XPRules.antiFarming(12, priorToday: 0) == 12)
        #expect(XPRules.antiFarming(12, priorToday: 1) == 12)
        #expect(XPRules.antiFarming(12, priorToday: 2) == 6)
        #expect(XPRules.antiFarming(12, priorToday: 3) == 3)
    }

    @Test func farmingOneCardEarnsLessInTheEngine() throws {
        let f = try GamificationFixture()
        f.advance(days: 7) // past the generous first week
        let first = try f.review("same", difficulty: 1).xp
        try f.review("same", difficulty: 1)
        let third = try f.review("same", difficulty: 1).xp
        #expect(first >= 10)
        #expect(third < first)
    }

    @Test func levelNeverDecreases() throws {
        // The curve is monotone in total XP...
        var last = 1
        for xp in stride(from: 0, through: 60_000, by: 37) {
            let level = LevelCurve.progress(totalXP: xp).level
            #expect(level >= last)
            last = level
        }
        // ...and nothing in the engine takes XP away: penalties, misses and refunds only touch meters.
        let f = try GamificationFixture()
        try f.arm(.responseCost, .examStake)
        try f.qualifyToday()
        let before = try f.state.level
        try f.engine.handle(.gateSkipped(useMercy: false))
        try f.engine.handle(.overlaySkipped)
        try f.engine.handle(.gateTimedOut(abandoned: true))
        try f.engine.handle(.examFinished(ExamCredit(kind: .weeklyMock, band: 2, integrity: .violation, failed: true)))
        f.advance(days: 4)
        let after = try f.state.level
        #expect(after.totalXP >= before.totalXP)
        #expect(after.level >= before.level)
        #expect(XPEventRecord(ts: 0, day: 0, amount: -50, source: "x", refId: nil).amount == 0)
    }

    @Test func scalesAboutOnePerTenXP() {
        #expect(ScalesRules.earned(totalXPBefore: 95, after: 105) == 1)
        #expect(ScalesRules.earned(totalXPBefore: 0, after: 99) == 9)
        #expect(ScalesRules.clampedChange(-20, balance: 5) == -5)
    }

    @Test func unverifiedExamsEarnNothing() throws {
        let f = try GamificationFixture()
        let fx = try f.engine.handle(.examFinished(ExamCredit(kind: .dailyCheck, band: 4, integrity: .unverifiable, correctItems: 20, productions: 2)))
        #expect(fx.xp == 0)
        #expect(try f.state.today.qualified == false)
        let clean = try f.engine.handle(.examFinished(ExamCredit(kind: .dailyCheck, band: 4, sectionBands: [4, 4.5], integrity: .clean)))
        #expect(clean.xp >= XPRules.examSection(band: 4) + XPRules.examSection(band: 4.5))
    }
}
