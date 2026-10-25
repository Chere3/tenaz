import Foundation
import Testing
@testable import TenazCore

struct MascotTests {
    static let config = try! StageConfig.load(from: ContentTests.contentRoot.appendingPathComponent("config/stages.json"))

    /// Stage 4+ need mastered notes and the public band; the engine fills both into the evidence.
    @Test func filledEvidenceCarriesMasteredAndPublicBand() throws {
        let f = try GamificationFixture()
        try f.engine.updateLearning(LearningSnapshot(notesIntroduced: 300, masteredNotes: 200, dueCount: 0))
        let filled = try f.engine.database.writer.write { db -> StageEvidence in
            let m = try f.engine.settle(db)
            return try f.engine.filledEvidence(db, StageEvidence(), mascot: m, today: f.today)
        }
        #expect(filled.masteredNotes == 200)
        #expect(filled.publicBand == nil)
    }

    @Test func moodTable() {
        let rows: [(MoodContext, MascotMood)] = [
            (MoodContext(vitality: 20, asleep: true), .asleep), // asleep wins: never interrupts
            (MoodContext(vitality: 20, repairInProgress: true), .regenerating),
            (MoodContext(vitality: 30), .sick),
            (MoodContext(justHealed: true), .proud),
            (MoodContext(celebrating: true), .ecstatic),
            (MoodContext(discovering: true), .curious),
            (MoodContext(dueCount: 40, inSession: true), .focused),
            (MoodContext(dueCount: 3, oldestOverdueHours: 30), .nagging),
            (MoodContext(dueCount: 10), .hungry),
            (MoodContext(spirit: 29), .sad),
            (MoodContext(vitality: 80, spirit: 80), .happy),
            (MoodContext(vitality: 60, spirit: 50), .neutral),
        ]
        for (context, mood) in rows { #expect(MoodResolver.mood(context) == mood, "\(context)") }
        #expect(Set(rows.map(\.1)) == Set(MascotMood.allCases))
        #expect(MascotMood.allCases.count == 12)
    }

    @Test func vitalityFloor15() throws {
        #expect(MascotMeters.clampVitality(-100) == 15)
        #expect(MascotMeters.clampVitality(140) == 100)
        // Daily costs at the cap for many days never take Tena below 15.
        let f = try GamificationFixture()
        try f.arm(.responseCost)
        for _ in 0..<6 {
            try f.engine.handle(.gateSkipped(useMercy: false))
            try f.engine.handle(.gateSkipped(useMercy: false))
            try f.qualifyToday() // keeps the soft freeze and welcome-back out of the way
            f.advance(days: 1)
        }
        let v = try f.state.mascot.vitality
        #expect(v >= MascotMeters.vitalityFloor)
        #expect(v <= 30)
    }

    @Test func stagesNeverRegress() throws {
        // Pure: the evaluator never returns less than the current stage, whatever the evidence.
        for current in 0...7 {
            #expect(StageEvaluator.nextStage(current: current, evidence: StageEvidence(), config: Self.config) >= current)
        }
        // Engine: stage 3 is provisional on day 1, then a weak placement keeps it ("catching up").
        let f = try GamificationFixture()
        try f.engine.updateStageEvidence(StageEvidence(onboardingDone: true, levelParagraphDone: true,
                                                       privateBand: StageEvidence.englishLevelPriorBand))
        #expect(try f.state.mascot.stage == 1)
        try f.qualifyToday()
        #expect(try f.state.mascot.stage == 3)
        #expect(try f.state.catchingUp == false)
        try f.engine.updateStageEvidence(StageEvidence(onboardingDone: true, levelParagraphDone: true, placementDone: true,
                                                       placementBand: 3.0, privateBand: 3.0))
        f.advance(days: 2)
        let s = try f.state
        #expect(s.mascot.stage == 3)
        #expect(s.catchingUp)
        #expect(s.stageName == "Juvenile")
    }

    @Test func stageFourNeedsEvidenceAndTimeFloor() {
        var e = StageEvidence(publicBand: 4.0, masteredNotes: 150)
        e.daysSinceStage = 27
        #expect(StageEvaluator.nextStage(current: 3, evidence: e, config: Self.config) == 3)
        e.daysSinceStage = 28
        #expect(StageEvaluator.nextStage(current: 3, evidence: e, config: Self.config) == 4)
        e.publicBand = 3.5
        #expect(StageEvaluator.nextStage(current: 3, evidence: e, config: Self.config) == 3)
    }

    @Test func stagesJsonHasPlanDefaults() {
        let c = Self.config
        #expect(c.stages.map(\.stage) == Array(0...7))
        #expect(c.stages.map { $0.requires.mastered ?? 0 } == [0, 0, 0, 0, 150, 400, 800, 1400])
        #expect(c.stages.map { $0.floor.days ?? 0 } == [0, 0, 0, 0, 28, 56, 70, 84])
        #expect(c.stages[7].requires.monthlyMocksAtBand == 2)
        #expect(c.microGrowthEvery == 25)
        #expect(c.cosmeticWeeks == [2, 4, 8, 12])
    }

    @Test func microGrowthEvery25Mastered() throws {
        #expect(MicroGrowth.steps(masteredHighWater: 24, every: 25) == 0)
        #expect(MicroGrowth.steps(masteredHighWater: 25, every: 25) == 1)
        #expect(MicroGrowth.steps(masteredHighWater: 99, every: 25) == 3)
        // The engine follows the high-water mark, so a lapse never shrinks Tena.
        let f = try GamificationFixture()
        try f.engine.updateLearning(LearningSnapshot(masteredNotes: 60))
        #expect(try f.state.microGrowth.steps == 2)
        try f.engine.updateLearning(LearningSnapshot(masteredNotes: 40))
        #expect(try f.state.microGrowth.steps == 2)
        f.advance(days: 14)
        #expect(try f.state.microGrowth.cosmeticMilestones == 1)
    }

    /// PLAN critique 11: with 5 new notes a day and Good answers, 150 mastered notes (stage 4's
    /// note gate) arrive well inside 10 weeks, so stage 4 then waits only on the band.
    @Test func fiveNewNotesADayReachesStage4Within10Weeks() {
        let fsrs = FSRS()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = GamificationFixture.timeZone
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 10))!
        var cards: [MemoryState] = []
        var correctRun: [Int] = []
        var stage = 3
        var stage4Day: Int?
        for d in 0..<70 {
            let now = start.addingTimeInterval(Double(d) * 86400)
            for _ in 0..<5 {
                cards.append(MemoryState())
                correctRun.append(0)
            }
            for i in cards.indices where cards[i].isNew || (cards[i].due ?? now) <= now.addingTimeInterval(12 * 3600) {
                cards[i] = fsrs.review(cards[i], rating: .good, at: now).card
                correctRun[i] += 1
            }
            let mastered = cards.indices.filter {
                Self.config.isMastered(stabilityDays: cards[$0].stability ?? 0, lastRecallsCorrect: correctRun[$0])
            }.count
            var e = StageEvidence(publicBand: 4.0, masteredNotes: mastered)
            e.daysSinceStage = d
            stage = StageEvaluator.nextStage(current: stage, evidence: e, config: Self.config)
            if stage == 4, stage4Day == nil { stage4Day = d }
        }
        #expect(stage == 4)
        #expect((stage4Day ?? 99) < 70)
    }
}

extension MascotTests {
    @Test func reviewsRegainUpToTheDaysLossOrBackTo80() {
        // Nothing lost and at 80: reviewing does not inflate Vitality.
        #expect(MascotMeters.regain(reviewsDone: 5, regainedToday: 0, lostToday: 0, vitality: 80) == 0)
        // Lost 10 today: +2 per 5 reviews until it is won back.
        #expect(MascotMeters.regain(reviewsDone: 5, regainedToday: 0, lostToday: 10, vitality: 70) == 2)
        #expect(MascotMeters.regain(reviewsDone: 25, regainedToday: 10, lostToday: 10, vitality: 80) == 0)
        // Sick from earlier days: heals by reviewing, up to 20 a day, never past 80.
        #expect(MascotMeters.regain(reviewsDone: 5, regainedToday: 0, lostToday: 0, vitality: 25) == 2)
        #expect(MascotMeters.regain(reviewsDone: 5, regainedToday: 20, lostToday: 0, vitality: 45) == 0)
        #expect(MascotMeters.regain(reviewsDone: 5, regainedToday: 0, lostToday: 0, vitality: 79) == 1)
        #expect(MascotMeters.regain(reviewsDone: 4, regainedToday: 0, lostToday: 10, vitality: 70) == 0)
    }
}
