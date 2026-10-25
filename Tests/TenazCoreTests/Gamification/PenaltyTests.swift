import Testing
@testable import TenazCore

struct PenaltyTests {
    @Test func noDrainWhenResponseCostOff() throws {
        let f = try GamificationFixture()
        try f.qualifyToday()
        f.advance(days: 14)
        let s = try f.state
        #expect(s.mascot.vitality == MascotMeters.start)
        #expect(s.today.vitalityLost == 0)
        // Only the mood moves: Spirit decays 6 a day without a session, so Tena turns sad.
        #expect(s.mascot.spirit < MascotMeters.sadBelow)
        #expect(s.mood == .sad)
    }

    @Test func drainStopsAfterTwoMissedDays() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        try f.qualifyToday()
        let start = try f.state.mascot.vitality
        f.advance(days: 5) // 4 missed days
        let s = try f.state
        // Two missed days cost -10 each, then the soft freeze stops the drain; the return day
        // (welcome back, 3+ missed) gives +10 once and pauses penalties.
        #expect(s.welcomeBack)
        #expect(s.mascot.vitality == start - 20 + PenaltyPolicy.welcomeBackVitality)
        let skip = try f.engine.handle(.gateSkipped(useMercy: false))
        #expect(skip.vitalityDelta == 0)
        #expect(skip.penalty?.outcome == .waived)
        #expect(try f.state.mascot.vitality == start - 10) // +10 only once
    }

    @Test func missedMinimumCostsScalesUnderResponseCost() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        try f.qualifyToday()
        let before = try f.state.scales
        #expect(before >= 20)
        f.advance(days: 2) // one missed day
        #expect(try f.state.scales == before - ScalesRules.missedDayCost)
    }

    @Test func idleTimeoutIsFreeAbandonedIsNot() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        #expect(try f.engine.handle(.gateTimedOut(abandoned: false)).vitalityDelta == 0)
        #expect(try f.engine.handle(.gateTimedOut(abandoned: true)).vitalityDelta == -10)
    }

    @Test func meetingClaimsFreeTwiceADayThenCounted() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        for _ in 0..<2 { #expect(try f.engine.handle(.meetingClaimUncorroborated(workCalendarVisible: true)).penalty == nil) }
        #expect(try f.engine.handle(.meetingClaimUncorroborated(workCalendarVisible: false)).penalty == nil)
        let charged = try f.engine.handle(.meetingClaimUncorroborated(workCalendarVisible: true))
        #expect(charged.vitalityDelta == -3)
        #expect(try f.state.today.meetingClaims == 4)
    }

    @Test func refundGivesThePenaltyBack() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        let start = try f.state.mascot.vitality
        let fx = try f.engine.handle(.gateSkipped(useMercy: false))
        let id = try #require(fx.penalty?.eventId)
        try f.engine.handle(.penaltyRefunded(eventId: id))
        try f.engine.handle(.penaltyRefunded(eventId: id)) // idempotent
        let s = try f.state
        #expect(s.mascot.vitality == start)
        #expect(s.today.penaltyEvents == 0)
    }

    @Test func refundGivesTheMercyTokenBack() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        let fx = try f.engine.handle(.gateSkipped(useMercy: true))
        #expect(try f.state.mercyLeft == PenaltyPolicy.mercyTokensPerMonth - 1)
        try f.engine.handle(.penaltyRefunded(eventId: try #require(fx.penalty?.eventId)))
        #expect(try f.state.mercyLeft == PenaltyPolicy.mercyTokensPerMonth)
    }

    @Test func repairTaskAtSickRegrowsLimbs() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost, .repairTask)
        // Drive Tena to Sick over two days of capped skips.
        for _ in 0..<2 {
            try f.engine.handle(.gateSkipped(useMercy: false))
            try f.engine.handle(.gateSkipped(useMercy: false))
            try f.qualifyToday()
            f.advance(days: 1)
        }
        try f.engine.handle(.gateSkipped(useMercy: false))
        var s = try f.state
        #expect(s.mascot.repairActive)
        #expect(s.mood == .regenerating)
        for i in 0..<15 { try f.review("r\(i)") }
        let fx = try f.engine.handle(.productionDone(Production(refId: "repair", quality: 0.7, words: 60)))
        #expect(fx.repairCompleted)
        s = try f.state
        #expect(!s.mascot.repairActive)
        #expect(s.mascot.vitality >= MascotMeters.healedVitality)
        #expect(s.mood == .proud)
        #expect(RepairTask.limbsRegrown(reviews: 10, paragraphDone: false) == 2)
    }

    @Test func escapeRateSuggestsDisable() {
        let today = 20261115
        func events(_ rule: String, day: Int, escaped: Int, fired: Int) -> [PenaltyEventRecord] {
            (0..<escaped).map { _ in PenaltyEventRecord(ruleId: rule, ts: 0, day: day, cost: "x", outcome: .escaped) }
                + (0..<fired).map { _ in PenaltyEventRecord(ruleId: rule, ts: 0, day: day, cost: "x", outcome: .fired) }
        }
        let lastWeek = LearningDays.adding(-9, to: today)
        let thisWeek = LearningDays.adding(-2, to: today)
        let log = events("responseCost", day: lastWeek, escaped: 7, fired: 3)
            + events("responseCost", day: thisWeek, escaped: 4, fired: 1)
            + events("strictGate", day: lastWeek, escaped: 7, fired: 3) // only one bad week
            + events("strictGate", day: thisWeek, escaped: 1, fired: 4)
            + events("examStake", day: lastWeek, escaped: 6, fired: 4) // exactly 60%: not above
            + events("examStake", day: thisWeek, escaped: 6, fired: 4)
        #expect(PenaltyExperimentLog.suggestDisable(log, today: today) == ["responseCost"])
    }

    @Test func extraCardsAfterMissedDay() throws {
        let f = try GamificationFixture()
        try f.arm(.extraCards)
        try f.qualifyToday()
        f.advance(days: 2)
        _ = try f.state
        let rows = try f.engine.database.reader.read { db in
            try PenaltyEventRecord.filter(sql: "task LIKE 'extraCards%'").fetchAll(db)
        }
        #expect(rows.count == 1)
        #expect(try f.state.mascot.vitality == MascotMeters.start) // extra cards cost no Vitality
    }
}
