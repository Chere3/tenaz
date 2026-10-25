import Testing
@testable import TenazCore

/// Penalty safety (PLAN §5.3): caps, recovery, floor, Contract delays. Lives in `SafetyTests`
/// so `swift test --filter SafetyTests` runs it with the rest.
extension SafetyTests {
    @Test func penaltyCapAndRecovery() throws {
        // Pure policy: the -30 cap and the 3-event recovery mode.
        var day = PenaltyPolicy.Day(vitalityLost: 20, penaltyEvents: 1)
        #expect(PenaltyPolicy.price(.gateSkip, day: day, ruleActive: true).vitality == -10)
        day.penaltyEvents = 3
        #expect(day.recoveryMode)
        #expect(PenaltyPolicy.price(.overlaySkip, day: day, ruleActive: true).outcome == .waived)
        #expect(!PenaltyPolicy.taskFits(minutes: 1, day: day))
        #expect(!PenaltyPolicy.taskFits(minutes: 6, day: PenaltyPolicy.Day()))

        // Engine: two emergency skips hit the -30 cap, the third event starts recovery mode.
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        try f.qualifyToday()
        let xpBefore = try f.state.level.totalXP
        let start = try f.state.mascot.vitality
        #expect(try f.engine.handle(.gateSkipped(useMercy: false)).vitalityDelta == -20)
        #expect(try f.engine.handle(.gateSkipped(useMercy: false)).vitalityDelta == -10)
        let third = try f.engine.handle(.overlaySkipped)
        #expect(third.vitalityDelta == 0)
        #expect(third.recoveryMode)
        let fourth = try f.engine.handle(.gateTimedOut(abandoned: true))
        #expect(fourth.vitalityDelta == 0)
        #expect(fourth.penalty?.outcome == .waived)
        let s = try f.state
        #expect(s.mascot.vitality == start - 30)
        #expect(s.recoveryMode)
        #expect(s.level.totalXP >= xpBefore) // level never decreases
        #expect(s.mascot.vitality >= MascotMeters.vitalityFloor)
    }

    @Test func emergencySkipPricedNeverRefused() throws {
        // With 0 Mercy tokens left, in recovery mode, the skip still goes through (only priced).
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        for _ in 0..<3 { #expect(try f.engine.handle(.gateSkipped(useMercy: true)).penalty?.mercyUsed == true) }
        #expect(try f.state.mercyLeft == 0)
        let fx = try f.engine.handle(.gateSkipped(useMercy: true))
        #expect(fx.penalty?.mercyUsed == false)
        #expect(fx.penalty?.outcome == .waived) // 4th event today: recovery mode
    }

    @Test func contractChangeDelay() throws {
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        #expect(try f.engine.contract().isActive(.responseCost, at: f.engine.nowMs))
        // Loosening waits 24 h, with a pending row that can be cancelled.
        let off = try #require(try f.engine.requestRuleChange(.responseCost, enabled: false))
        #expect(off.direction == .loosen)
        #expect(try f.engine.contract().pending(at: f.engine.nowMs).count == 1)
        f.advance(hours: 23.9)
        #expect(try f.engine.contract().isActive(.responseCost, at: f.engine.nowMs))
        f.advance(hours: 0.2)
        #expect(try !f.engine.contract().isActive(.responseCost, at: f.engine.nowMs))

        // Cancelled loosening never takes effect.
        try f.engine.requestRuleChange(.repairTask, enabled: true)
        f.advance(days: 1)
        let pending = try #require(try f.engine.requestRuleChange(.repairTask, enabled: false))
        try f.engine.cancelPendingChange(id: try #require(pending.id))
        f.advance(days: 2)
        #expect(try f.engine.contract().isActive(.repairTask, at: f.engine.nowMs))
        #expect(try f.engine.contract().inForce(.repairTask, at: f.engine.nowMs)?.enabled == true)
    }

    @Test func contractLoosenDelayedTightenNextDay() throws {
        let f = try GamificationFixture() // Monday 10:00
        let on = try #require(try f.engine.requestRuleChange(.responseCost, enabled: true))
        #expect(on.direction == .tighten)
        f.advance(hours: 17.9) // Tuesday 03:54
        #expect(try !f.engine.contract().isActive(.responseCost, at: f.engine.nowMs))
        f.advance(hours: 0.2) // Tuesday 04:06
        #expect(try f.engine.contract().isActive(.responseCost, at: f.engine.nowMs))
        // A stronger parameter on a rule that stays on is a tightening; unsure means loosening.
        let raise = try #require(try f.engine.requestRuleChange(.responseCost, enabled: true, params: "{\"x\":2}", tightens: true))
        #expect(raise.direction == .tighten)
        let unsure = try #require(try f.engine.requestRuleChange(.responseCost, enabled: true, params: "{\"x\":1}"))
        #expect(unsure.direction == .loosen)
        #expect(unsure.effectiveAt - f.engine.nowMs == Contract.loosenDelayMs)
    }

    @Test func everyRuleShipsOff() throws {
        let f = try GamificationFixture()
        for kind in PenaltyRuleKind.allCases { #expect(!Contract.empty.isActive(kind, at: f.engine.nowMs)) }
        // With no rule on, every skip and timeout is free.
        let events: [GamificationEvent] = [.gateSkipped(useMercy: false), .overlaySkipped, .gateTimedOut(abandoned: true),
                                           .meetingClaimUncorroborated(workCalendarVisible: true)]
        for event in events {
            let fx = try f.engine.handle(event)
            #expect(fx.vitalityDelta == 0)
            #expect(fx.penalty == nil)
        }
        #expect(try f.engine.requestRuleChange(.tivraFunAppBlock, enabled: true) == nil)
    }
}
